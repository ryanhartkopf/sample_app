# A simple example of immutable infrastructure
A Node.js application and MongoDB database deployed using Packer and Terraform on AWS.

## About the app
The backend and routing are contained in the [server.js](server.js) file, and the AngularJS front end is contained in the [public/](public/) directory. This sample app was pulled from the [Node Todo](https://github.com/scotch-io/node-todo) project from Scotch.io. Our single table "Todo" will be stored in a MongoDB database. The service is divided into 2 layers, app and data.

## Infrastructure - app layer
The app layer infrastructure is immutable. To quote Florian Motlik from CodeShip, "Immutable infrastructure is comprised of immutable components that are replaced for every deployment, rather than being updated in-place." [(Source)](https://blog.codeship.com/immutable-infrastructure/). This allows us to avoid configuration drift, memory leaks, unpatched instances, and the dreaded reboot of an instance with 439 days of uptime at 2 in the morning. The app layer will be deployed using Terraform with a single Elastic Load Balancer and an Auto-Scaling Group of EC2 instances. The instance AMIs are built using Packer.

## Infrastructure - data layer
The data layer is deployed in a similar manner, but the immutable MongoDB instances are backed by mutable EBS volumes that contain application state. Each MongoDB instance is deployed in an Auto-Scaling Group consisting of one EC2 instance, so if the instance goes down for any reason it will be re-launched automatically.

## Deployment
To build the infrastructure, clone the GitHub repo, give Terraform some credentials [(see Terraform docs)](https://www.terraform.io/docs/providers/aws/), download and install [Terragrunt](https://github.com/gruntwork-io/terragrunt/releases) for remote state management, then run:

```cd terraform/<app>
terragrunt apply
```

Terragrunt will take care of creating S3 buckets and initializing your remote state automatically.

Once the network configuration is deployed and Jenkins is configured, we can use Packer to create AMIs through a Jenkins job. I used Nicolás Bevacqua's excellent tutorial ["Immutable Deployments and Packer"](https://ponyfoo.com/articles/immutable-deployments-packer) as an example, and modified to use the amazon-chroot builder for a performance boost. This requires some funky sudo action to allow Jenkins to mount volumes.

I like to build AMI images in layers to allow for faster deployment of code changes. To make the base AMI, we'll update all OS packages, configure some swap space, and copy an init conf file to the image:

```sudo -H -u ubuntu bash -c 'sudo packer build packer/base.json | tee /tmp/base.log'

BASE_AMI=$(tail -2 < /tmp/base.log | grep ami | cut -d ' ' -f 2)
echo $BASE_AMI >> /tmp/base_ami
```

After the base image has been created, the deploy image can be rebuilt very quickly. The steps are similar to the base image:

```sudo -H -u ubuntu /bin/bash -c 'sudo packer build -var SOURCE_AMI=$(tail -1 /tmp/base_ami) packer/app.json | tee /tmp/app.log'

APP_AMI=$(tail -2 < /tmp/app.log | grep ami | cut -d ' ' -f 2)
echo $APP_AMI >> /tmp/app_ami
```

The app AMI can then be used to deploy our immutable application layer. We can assign the app AMI ID to a "TF_VAR" environment variable so Terraform will recognize it. Here is an example of a possible Jenkins configuration:

```cd terraform/services/app
export TF_VAR_source_ami=$(tail -1 /tmp/app_ami)
terragrunt plan --terragrunt-non-interactive -out=tf.out && terragrunt apply --terragrunt-non-interactive tf.out
```

Running `terraform apply` against this configuration for the first time will launch a new ELB and auto-scaling group. When the AMI ID is modified, the auto-scaling launch configuration will change, forcing a new auto-scaling group to be provisioned by updating its `name` parameter. Lifecycle management of the current auto-scaling group in [terraform/services/app/main.tf](terraform/services/app/main.tf) prevents Terraform from deleting the old auto-scaling group until the new instances have been launched and passed their health checks. With these simple options, it is trivial to perform rolling deployments of asynchronous services using Terraform and auto-scaling groups.

## Putting it all together
Once you have your Jenkins jobs created, a Pipeline can be used to vizualize your deployment flow. Here is a simple example of a Pipeline job configuration:

```stage('Configure VPC and Jenkins') {
    build 'terraform-vpc'
    build 'terraform-services-jenkins'
}
stage('Create Base AMI') {
    build 'packer-build-base'
}
stage('Create App AMI') {
    build 'packer-build-app'
}
stage('Rolling App Deployment') {
    build 'terraform-services-app'
}
```
