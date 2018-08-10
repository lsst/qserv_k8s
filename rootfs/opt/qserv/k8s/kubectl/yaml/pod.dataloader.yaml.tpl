apiVersion: v1
kind: Pod
metadata:
  name: dataloader 
  labels:
    app: qserv
    node: dataloader 
spec:
  subdomain: qserv
  containers:
    - name: mariadb
      image: "<INI_IMAGE>"
      imagePullPolicy: Always
      command:
        - sh
        - /config-start/start.sh
      livenessProbe:
        tcpSocket:
          port: mariadb-port
        initialDelaySeconds: 15
        periodSeconds: 20
      readinessProbe:
        tcpSocket:
          port: mariadb-port
        initialDelaySeconds: 5
        periodSeconds: 10
      ports:
      - name: mariadb-port
        containerPort: 3306
      volumeMounts:
      - name: config-mariadb-etc
        mountPath: /config-mariadb-etc
      - name: config-mariadb-start
        mountPath: /config-start
    - name: dataloader 
      command:
        - tail 
        - -f
        - /dev/null
      image: "<INI_IMAGE>"
      imagePullPolicy: Always
      ports:
      volumeMounts:
      - mountPath: /home/qserv/.lsst
        name: config-dot-lsst
      - mountPath: /secret
        name: secret-wmgr
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
    - name: config-sql
      configMap:
        name: config-sql
    - name: secret-wmgr
      secret:
        secretName: secret-wmgr
  restartPolicy: Never
