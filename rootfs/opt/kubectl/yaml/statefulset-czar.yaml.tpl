apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: czar
  labels:
    tier: czar
    app: qserv
spec:
  serviceName: qserv
  podManagementPolicy: "Parallel"
  replicas: 1
  selector:
    matchLabels:
      tier: czar
      app: qserv
  template:
    metadata:
      labels:
        tier: czar
        app: qserv
    spec:
      containers:
        - name: mariadb
          image: "<INI_IMAGE>"
          imagePullPolicy: Always
          command:
            - sh
            - /config-start/start.sh
          livenessProbe:
            tcpSocket:
              port: mariadb
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            tcpSocket:
              port: mariadb
            initialDelaySeconds: 5
            periodSeconds: 10
          ports:
          - name: mariadb
            containerPort: 3306
          volumeMounts:
          - name: config-mariadb-etc
            mountPath: /config-etc
          - name: config-mariadb-start
            mountPath: /config-start
          - mountPath: /qserv/data
            name: qserv-data
        - name: xrootd
          image: "<INI_IMAGE>"
          imagePullPolicy: Always
          args:
            - /config-start/start.sh
          command:
            - sh
          env:
            - name: CZAR
              valueFrom:
                configMapKeyRef:
                  name: config-domainnames
                  key: CZAR
            - name: QSERV_DOMAIN
              valueFrom:
                configMapKeyRef:
                  name: config-domainnames
                  key: QSERV_DOMAIN
            - name: CZAR_DN
              valueFrom:
                configMapKeyRef:
                  name: config-domainnames
                  key: CZAR_DN
          securityContext:
            capabilities:
              add:
              - IPC_LOCK
          volumeMounts:
          - name: config-xrootd-etc
            mountPath: /config-etc
          - name: config-xrootd-start
            mountPath: /config-start
          - mountPath: /qserv/data
            name: qserv-data
        - name: proxy
          command:
            - sh
            - /config-start/start.sh
          image: "<INI_IMAGE>"
          imagePullPolicy: Always
          env:
            - name: CZAR
              valueFrom:
                configMapKeyRef:
                  name: config-domainnames
                  key: CZAR
          livenessProbe:
            tcpSocket:
              port: proxy
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            tcpSocket:
              port: proxy
            initialDelaySeconds: 5
            periodSeconds: 10
          ports:
          - name: proxy
            containerPort: 4040
          volumeMounts:
          - mountPath: /home/qserv/.lsst
            name: config-dot-lsst
          - mountPath: /config-start
            name: config-proxy-start
          - mountPath: /config-etc
            name: config-proxy-etc
          - mountPath: /qserv/data
            name: qserv-data
          - mountPath: /secret
            name: secret-wmgr
        - name: wmgr
          command:
            - sh
            - /config-start/start.sh
          env:
            - name: CZAR_DN
              valueFrom:
                configMapKeyRef:
                  name: config-domainnames
                  key: CZAR_DN
          image: "<INI_IMAGE>"
          imagePullPolicy: Always
          livenessProbe:
            tcpSocket:
              port: 5012
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            tcpSocket:
              port: 5012
            initialDelaySeconds: 5
            periodSeconds: 10
          volumeMounts:
          - mountPath: /config-start
            name: config-wmgr-start
          - mountPath: /config-etc
            name: config-wmgr-etc
          - mountPath: /qserv/data
            name: qserv-data
          - mountPath: /secret
            name: secret-wmgr
      initContainers:
        - command:
          - sh
          - /config-mariadb/mariadb-configure.sh
          env:
            - name: CZAR
              valueFrom:
                configMapKeyRef:
                  name: config-domainnames
                  key: CZAR
          image: "<INI_IMAGE>"
          imagePullPolicy: Always
          name: init-data-dir
          volumeMounts:
          - mountPath: /config-mariadb
            name: config-mariadb-configure
          - mountPath: /config-etc
            name: config-mariadb-etc
          - mountPath: /config-sql/czar
            name: config-sql-czar
          - mountPath: /qserv/data
            name: qserv-data
      volumes:
        - name: config-dot-lsst
          configMap:
            name: config-dot-lsst
        - name: config-mariadb-configure
          configMap:
            name: config-mariadb-configure
        - name: config-mariadb-start
          configMap:
            name: config-mariadb-start
        - name: config-sql-czar
          configMap:
            name: config-sql-czar
        - name: config-xrootd-etc
          configMap:
            name: config-xrootd-etc
        - name: config-xrootd-start
          configMap:
            name: config-xrootd-start
        - name: config-domainnames
          configMap:
            name: config-domainnames
        - name: config-mariadb-etc
          configMap:
            name: config-mariadb-etc
        - name: config-proxy-etc
          configMap:
            name: config-proxy-etc
        - name: config-proxy-start
          configMap:
            name: config-proxy-start
            defaultMode: 0755
        - name: config-wmgr-etc
          configMap:
            name: config-wmgr-etc
        - name: config-wmgr-start
          configMap:
            name: config-wmgr-start
        - name: secret-wmgr
          secret:
            secretName: secret-wmgr
  volumeClaimTemplates:
  - metadata:
      name: qserv-data
    spec:
      accessModes: [ "ReadWriteOnce" ]