COMMIT = $(shell git rev-parse --short HEAD)
CONTAINER_ID = $(shell docker run -d local/grafana-annotate:latest)
TF_DIR = deploy/terraform/
TF_PLAN_FILE = "plan.out"
# TODO - add -input=false
TF_GLOBAL_OPTS = -chdir=$(TF_DIR)
TF_OPTS = -input=false
TF_CMD = terraform $(TF_GLOBAL_OPTS)
ARCHIVE_FILE = "grafana-annotate.zip"

.PHONY: build tf-*

# TODO - check for a built image of the commit before running docker build. May require checking
build:
	docker build \
		--file ./cmd/grafana-annotate/Dockerfile \
		--tag=local/grafana-annotate:$(COMMIT) \
		--tag=local/grafana-annotate:latest .

# TODO - make this resilient
test: build
	# TODO - use better logic here instead of hiding errors
	@docker kill grafana-annotate-test && docker rm grafana-annotate-test || echo
	docker run --name grafana-annotate-test --env-file secrets.env -d -v ~/.aws-lambda-rie:/aws-lambda --entrypoint /aws-lambda/aws-lambda-rie  -p 9000:8080 grafana-annotate-test /main

# TODO - add test/vet to another target
go-test:
	@go test -v -cover -race ./...

go-vet:
	@go vet ./...

# TODO - check if output file already exists
build-zip: build
	docker cp $(CONTAINER_ID):/grafana-annotate .
	zip $(ARCHIVE_FILE) grafana-annotate
	mv $(ARCHIVE_FILE) $(TF_DIR)
	rm grafana-annotate
	docker rm $(CONTAINER_ID)

# See https://learn.hashicorp.com/tutorials/terraform/automate-terraform
# TODO - make this run faster by checking for init output before running Terraform init
tf-init:
	$(TF_CMD) init $(TF_OPTS)
	#$(TF_CMD) init

# TODO - check for plan file before running terraform plan
# build-zip is needed because the zip file needs to be checked for a changed checksum
tf-plan: tf-init build-zip
	$(TF_CMD) plan $(TF_OPTS) -out $(TF_PLAN_FILE)

tf-apply: tf-plan
	# No $(TF_OPTS) to require a manual approval
	$(TF_CMD) apply $(TF_PLAN_FILE)

# TODO - implement
# tf-destroy: tf-plan

# TODO - grafana target for better testing
# grafana target

# TODO - allow testing using AWS RIE
# See https://docs.aws.amazon.com/lambda/latest/dg/images-test.html
#rie:
#	@which aws-lambda-rie
