#!/bin/bash


DOCKER_USER="zakerru"
START_PORT=30001


PORT_COUNTER=$START_PORT

for folder in site*; do
  if [ -d "$folder" ]; then
    SITE_NAME=$folder
    CURRENT_PORT=$PORT_COUNTER

    echo "Processing site: $SITE_NAME"


    echo "Building Docker image..."
    docker build -t ${DOCKER_USER}/nginx-${SITE_NAME}:latest ./${folder}

    echo "Pushing image to Docker Hub..."
    docker push ${DOCKER_USER}/nginx-${SITE_NAME}:latest

    echo "Applying Kubernetes manifests..."
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-${SITE_NAME}
  labels:
    app: nginx-${SITE_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-${SITE_NAME}
  template:
    metadata:
      labels:
        app: nginx-${SITE_NAME}
    spec:
      volumes:
      - name: shared-logs
        emptyDir:
          sizeLimit: 50Mi

      containers:
      - name: nginx
        image: ${DOCKER_USER}/nginx-${SITE_NAME}:latest
        imagePullPolicy: Always
        resources:
          requests:
            memory: "500Mi"
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 15
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 10
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx

      - name: parser
        image: ${DOCKER_USER}/parser:latest
        imagePullPolicy: Always
        resources:
          requests:
            memory: "1000Mi"

        env:
        - name: SITE_NAME
          value: "${SITE_NAME}"
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx
---
apiVersion: v1
kind: Service
metadata:
  name: service-${SITE_NAME}
spec:
  type: NodePort
  selector:
    app: nginx-${SITE_NAME}
  ports:
    - port: 80
      targetPort: 80
      nodePort: ${CURRENT_PORT}
EOF

    echo "Done! Site $SITE_NAME is running on port: $CURRENT_PORT"
    PORT_COUNTER=$((PORT_COUNTER + 1))
  fi
done
