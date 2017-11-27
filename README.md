# A simple example of immutable infrastructure
A Node.js application and MongoDB database deployed using Packer and Terraform on AWS.

## About the app
The backend and routing are contained in the [server.js](server.js) file, and the AngularJS front end is contained in the [public/](public/) directory. This sample app was pulled from the [Node Todo](https://github.com/scotch-io/node-todo) project from Scotch.io. Our single table "Todo" will be stored in a MongoDB database. The service is divided into 2 layers, app and data.

## Infrastructure - app layer
The app layer infrastructure is immutable. To quote Florian Motlik from CodeShip, "Immutable infrastructure is comprised of immutable components that are replaced for every deployment, rather than being updated in-place." [(Source)](https://blog.codeship.com/immutable-infrastructure/). This allows us to avoid configuration drift, memory leaks, unpatched instances, and the dreaded reboot of an instance with 439 days of uptime at 2 in the morning. The app layer will be deployed using Terraform with a single Elastic Load Balancer and an Auto-Scaling Group of EC2 instances. The instance AMIs are built using Packer.

## Infrastructure - data layer
The data layer is deployed in a similar manner, but the immutable MongoDB instances are backed by mutable EBS volumes that contain application state. Each MongoDB instance is deployed in an Auto-Scaling Group consisting of one EC2 instance, so if the instance goes down for any reason it will be re-launched automatically.

## Deployment
To build the infrastructure, clone the GitHub repo, give Terraform some credentials [(see Terraform docs)](https://www.terraform.io/docs/providers/aws/), then run:

```cd terraform
terraform init
terraform build```

Once the network configuration is deployed, we can use Packer to create AMIs. I used Nicolás Bevacqua's excellent tutorial ["Immutable Deployments and Packer"](https://ponyfoo.com/articles/immutable-deployments-packer) as an example. To build the base image:

```packer build \
-var VPC_ID=vpc-12345678
-var SUBNET_ID=subnet-12345687
packer/base.json | tee packer/base.log```

Then extract the AMI ID:

BASE_AMI=$(tail -1 < deploy/log/packer-primal.log | cut -d ' ' -f 2)


