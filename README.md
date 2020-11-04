# Terraform template for static website hosting with S3 and Cloudfront

This terraform setup can be used to setup the AWS infrastructure
for hosting a static website or SPA.

## Resources

This setup creates the following resources:

- S3 bucket for the website files
- Cloudfront distribution as CDN
- Route53 records for the given domain

The S3 bucket is configured with a Cloudfront origin access id, so the hosted site cannot be accessed directly via the S3 URL, but only via it's Cloudfront distribution.

![example](https://miro.medium.com/max/1288/0*GOJnOMi5MiIIM8JG.png "Infrastructure illustration")

(Source: https://itnext.io/static-website-over-https-with-s3-cloudfront-gatsby-continuously-delivered-b2b33bb7fa29)

### Get Started building your own infrastructure

- Install terraform on MacOS with `brew install terraform`
- create your own `secrets.tfvars` based on `secrets.example.tfvars`, insert the values for your AWS access key and secrets. If you don't create your `secrets.tfvars`, don't worry. Terraform will interactively prompt you for missing variables later on. You can also create your `terraform.tfvars` file to manage non-secret values for different environments or projects with the same infrastructure
- execute `terraform init`, it will initialize your local terraform and connect it to the state store, and it will download all the necessary providers
- execute `terraform plan -var-file="secrets.tfvars" -out="out.plan"` - this will calculate the changes terraform has to apply and creates a plan. If there are changes, you will see them. Check if any of the changes are expected, especially deletion of infrastructure.
- if everything looks good, you can execute the changes with `terraform apply out.plan`

### s3_sync.sh

This script can be used to deploy the latest version of your site to the S3 bucket. It sets the caching headers right and makes a cloudfront invalidation unnecessary.

Usage example with github actions:

```
- name: Upload to S3 bucket 🚀
    id: upload-to-s3
    env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        AWS_DEFAULT_REGION: eu-central-1
        AWS_S3_BUCKET_NAME: website.com
    run: |
        bash s3_sync.sh --bucket=$AWS_S3_BUCKET_NAME --source-folder=dist
```