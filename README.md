# Coworking Space Service Extension
The Coworking Space Service is a set of APIs that enables users to request one-time tokens and administrators to authorize access to a coworking space. This service follows a microservice pattern and the APIs are split into distinct services that can be deployed and managed independently of one another.

For this project, you are a DevOps engineer who will be collaborating with a team that is building an API for business analysts. The API provides business analysts basic analytics data on user activity in the service. The application they provide you functions as expected locally and you are expected to help build a pipeline to deploy it in Kubernetes.

## Getting Started

### Dependencies
#### Local Environment
1. Python Environment - run Python 3.6+ applications and install Python dependencies via `pip`
2. Docker CLI - build and run Docker images locally
3. `kubectl` - run commands against a Kubernetes cluster
4. `helm` - apply Helm Charts to a Kubernetes cluster

#### Remote Resources
1. AWS CodeBuild - build Docker images remotely
2. AWS ECR - host Docker images
3. Kubernetes Environment with AWS EKS - run applications in k8s
4. AWS CloudWatch - monitor activity and logs in EKS
5. GitHub - pull and clone code

### Setup
#### 1. Configure a Database
Set up a Postgres database using a Helm Chart.

1. Set up Bitnami Repo
```bash
helm repo add <REPO_NAME> https://charts.bitnami.com/bitnami
```

2. Install PostgreSQL Helm Chart
```
helm install <SERVICE_NAME> <REPO_NAME>/postgresql
```

This should set up a Postgre deployment at `<SERVICE_NAME>-postgresql.default.svc.cluster.local` in your Kubernetes cluster. You can verify it by running `kubectl svc`

By default, it will create a username `postgres`. The password can be retrieved with the following command:
```bash
export POSTGRES_PASSWORD=$(kubectl get secret --namespace default <SERVICE_NAME>-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

echo $POSTGRES_PASSWORD
```

<sup><sub>* The instructions are adapted from [Bitnami's PostgreSQL Helm Chart](https://artifacthub.io/packages/helm/bitnami/postgresql).</sub></sup>

3. Test Database Connection
The database is accessible within the cluster. This means that when you will have some issues connecting to it via your local environment. You can either connect to a pod that has access to the cluster _or_ connect remotely via [`Port Forwarding`](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

* Connecting Via Port Forwarding
```bash
kubectl port-forward --namespace default svc/<SERVICE_NAME>-postgresql 5432:5432 &
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432
```

* Connecting Via a Pod
```bash
kubectl exec -it <POD_NAME> bash
PGPASSWORD="<PASSWORD HERE>" psql postgres://postgres@<SERVICE_NAME>:5432/postgres -c <COMMAND_HERE>
```

4. Run Seed Files
We will need to run the seed files in `db/` in order to create the tables and populate them with data.

```bash
kubectl port-forward --namespace default svc/<SERVICE_NAME>-postgresql 5432:5432 &
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432 < <FILE_NAME.sql>
```

### 2. Running the Analytics Application Locally
In the `analytics/` directory:

1. Install dependencies
```bash
pip install -r requirements.txt
```
2. Run the application (see below regarding environment variables)
```bash
<ENV_VARS> python app.py
```

There are multiple ways to set environment variables in a command. They can be set per session by running `export KEY=VAL` in the command line or they can be prepended into your command.

* `DB_USERNAME`
* `DB_PASSWORD`
* `DB_HOST` (defaults to `127.0.0.1`)
* `DB_PORT` (defaults to `5432`)
* `DB_NAME` (defaults to `postgres`)

If we set the environment variables by prepending them, it would look like the following:
```bash
DB_USERNAME=username_here DB_PASSWORD=password_here python app.py
```
The benefit here is that it's explicitly set. However, note that the `DB_PASSWORD` value is now recorded in the session's history in plaintext. There are several ways to work around this including setting environment variables in a file and sourcing them in a terminal session.

3. Verifying The Application
* Generate report for check-ins grouped by dates
`curl <BASE_URL>/api/reports/daily_usage`

* Generate report for check-ins grouped by users
`curl <BASE_URL>/api/reports/user_visits`

## Project Instructions
This project involves deploying a PostgreSQL database on an AWS EKS (Elastic Kubernetes Service) cluster, creating a coworking analytics application, and deploying it using Docker and Kubernetes. Here's a breakdown of the steps involved:

### 1. **Set Up AWS and EKS Cluster**

#### a. **IAM Permissions and AWS CLI Configuration**
   - Ensure that you have the necessary IAM permissions and your AWS CLI is configured correctly:
     ```bash
     aws sts get-caller-identity
     aws configure
     ```

#### b. **Create an EKS Cluster**
   - Use `eksctl` to create a Kubernetes cluster:
     ```bash
     eksctl create cluster --name my-cluster --region us-east-1 --nodegroup-name my-nodes --node-type t3.small --nodes 1 --nodes-min 1 --nodes-max 2
     ```

#### c. **Update Kubeconfig**
   - Update the context in your local kubeconfig file:
     ```bash
     aws eks --region us-east-1 update-kubeconfig --name my-cluster
     ```

#### d. **Verify Context**
   - Check the current Kubernetes context:
     ```bash
     kubectl config current-context
     ```

### 2. **PostgreSQL Setup in Kubernetes**

#### a. **Create YAML Configurations**
   - **PersistentVolumeClaim (PVC)**
     ```yaml
     apiVersion: v1
     kind: PersistentVolumeClaim
     metadata:
       name: postgresql-pvc
     spec:
       storageClassName: gp2
       accessModes:
         - ReadWriteOnce
       resources:
         requests:
           storage: 1Gi
     ```

   - **PersistentVolume (PV)**
     ```yaml
     apiVersion: v1
     kind: PersistentVolume
     metadata:
       name: my-manual-pv
     spec:
       capacity:
         storage: 1Gi
       accessModes:
         - ReadWriteOnce
       persistentVolumeReclaimPolicy: Retain
       storageClassName: gp2
       hostPath:
         path: "/mnt/data"
     ```

   - **PostgreSQL Deployment**
     ```yaml
     apiVersion: apps/v1
     kind: Deployment
     metadata:
       name: postgresql
     spec:
       selector:
         matchLabels:
           app: postgresql
       template:
         metadata:
           labels:
             app: postgresql
         spec:
           containers:
           - name: postgresql
             image: postgres:latest
             env:
             - name: POSTGRES_DB
               value: mydatabase
             - name: POSTGRES_USER
               value: myuser
             - name: POSTGRES_PASSWORD
               value: mypassword
             ports:
             - containerPort: 5432
             volumeMounts:
             - mountPath: /var/lib/postgresql/data
               name: postgresql-storage
           volumes:
           - name: postgresql-storage
             persistentVolumeClaim:
               claimName: postgresql-pvc
     ```

#### b. **Apply the YAML Files**
   - Apply the configurations to the cluster:
     ```bash
     kubectl apply -f pvc.yaml
     kubectl apply -f pv.yaml
     kubectl apply -f postgresql-deployment.yaml
     ```

#### c. **Verify Pods**
   - Check if the Postgres pod is running:
     ```bash
     kubectl get pods
     ```

#### d. **Connect to Postgres Pod**
   - Use `kubectl exec` to access the pod and the Postgres shell:
     ```bash
     kubectl exec -it <postgres-pod-name> -- bash
     psql -U myuser -d mydatabase
     ```

### 3. **Expose PostgreSQL Using Port Forwarding**

#### a. **Create a Service**
   - **Service YAML:**
     ```yaml
     apiVersion: v1
     kind: Service
     metadata:
       name: postgresql-service
     spec:
       ports:
       - port: 5432
         targetPort: 5432
       selector:
         app: postgresql
     ```
   - Apply the service configuration:
     ```bash
     kubectl apply -f postgresql-service.yaml
     ```

#### b. **Set Up Port Forwarding**
   - Open port forwarding to your local machine:
     ```bash
     kubectl port-forward service/postgresql-service 5433:5432 &
     ```

### 4. **Run Seed Files and Populate Database**

#### a. **Install PostgreSQL Client**
   ```bash
   apt update
   apt install postgresql postgresql-contrib
   ```

#### b. **Run Seed Files**
   - Import the SQL files to populate the database:
     ```bash
     PGPASSWORD="$DB_PASSWORD" psql --host 127.0.0.1 -U myuser -d mydatabase -p 5433 < <FILE_NAME.sql>
     ```

### 5. **Run the Application Locally**

#### a. **Install Dependencies**
   ```bash
   apt update
   apt install build-essential libpq-dev
   pip install --upgrade pip setuptools wheel
   pip install -r requirements.txt
   ```

#### b. **Run the Application**
   - Set environment variables and run the app:
     ```bash
     export DB_USERNAME=myuser
     export DB_PASSWORD=${POSTGRES_PASSWORD}
     export DB_HOST=127.0.0.1
     export DB_PORT=5433
     export DB_NAME=mydatabase
     python app.py
     ```

### 6. **Dockerize the Application**

#### a. **Build Docker Image**
   - Create a Dockerfile and build the image:
     ```bash
     docker build -t test-coworking-analytics .
     ```

#### b. **Run the Docker Image**
   - Test the Docker image with host networking:
     ```bash
     docker run --network="host" test-coworking-analytics
     ```

### 7. **CI/CD with CodeBuild and Kubernetes Deployment**

   - Once the app is verified, you can proceed to set up continuous integration with AWS CodeBuild and deploy it to your Kubernetes cluster.

This provides the full workflow from creating an EKS cluster, setting up PostgreSQL, running a local application, Dockerizing it, and preparing for deployment. Let me know if you need details on a specific part!

### Deliverables
1. `Dockerfile` -->
   Link given here https://github.com/tusharagarwal19/cd12355-microservices-aws-kubernetes-project-starter/blob/main/Dockerfile
2. Screenshot of AWS CodeBuild pipeline
   ![image](https://github.com/user-attachments/assets/3418e8b3-5742-43dd-878d-6f1ca4a91076)

3. Screenshot of AWS ECR repository for the application's repository
   ![image](https://github.com/user-attachments/assets/d88cac50-de0a-4166-a1ad-50339d181eda)

4. Screenshot of `kubectl get svc`
   ![image](https://github.com/user-attachments/assets/21eeccd0-284a-4b63-a63b-967ee06a03e6)

5. Screenshot of `kubectl get pods`
   ![image](https://github.com/user-attachments/assets/1297f515-897c-4fc3-aba1-48cc71adb7e8)
 
6. Screenshot of `kubectl describe svc <DATABASE_SERVICE_NAME>`
   ![image](https://github.com/user-attachments/assets/61cd3244-5685-44aa-b426-5b44e6d531a1)

7. Screenshot of `kubectl describe deployment <SERVICE_NAME>`
  ![image](https://github.com/user-attachments/assets/2ff3d998-519b-48f1-a875-77f77ac4b2d9)

9. All Kubernetes config files used for deployment (ie YAML files)
    All YAML files are present at the repo link --> https://github.com/tusharagarwal19/cd12355-microservices-aws-kubernetes-project-starter/tree/main/deployment

10. Screenshot of configuration of cloud watch logs
    ![image](https://github.com/user-attachments/assets/f909d236-8760-4b9f-818d-7276621c3d5d)
    
11. Screenshot of AWS CloudWatch logs for the application
    ![image](https://github.com/user-attachments/assets/c6255ed3-6c0a-4643-a5a5-2f0046b8cd6c)
    
12. Screenshot of CloudWatch logs showing the logs of the application, which periodically prints the database output.    
    <img width="931" alt="image" src="https://github.com/user-attachments/assets/0d840744-6fb7-448f-a07a-aaa6cd0d7756">



14. `README.md` file in your solution that serves as documentation for your user to detail how your deployment process works and how the user can deploy changes. The details should not simply rehash what you have done on a step by step basis. Instead, it should help an experienced software developer understand the technologies and tools in the build and deploy process as well as provide them insight into how they would release new builds.


### Stand Out Suggestions
Please provide up to 3 sentences for each suggestion. Additional content in your submission from the standout suggestions do _not_ impact the length of your total submission.
1. Specify reasonable Memory and CPU allocation in the Kubernetes deployment configuration
2. In your README, specify what AWS instance type would be best used for the application? Why?
3. In your README, provide your thoughts on how we can save on costs?

### Best Practices
* Dockerfile uses an appropriate base image for the application being deployed. Complex commands in the Dockerfile include a comment describing what it is doing.
* The Docker images use semantic versioning with three numbers separated by dots, e.g. `1.2.1` and  versioning is visible in the  screenshot. See [Semantic Versioning](https://semver.org/) for more details.
