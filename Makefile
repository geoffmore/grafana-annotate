build:
	@docker build -t grafana-annotate-test .

# TODO - make this resilient
test: build
	@docker kill grafana-annotate-test 2> /dev/null
	docker rm grafana-annotate-test 2> /dev/null
	docker run --name grafana-annotate-test --env-file secrets.env -d -v ~/.aws-lambda-rie:/aws-lambda --entrypoint /aws-lambda/aws-lambda-rie  -p 9000:8080 grafana-annotate-test /main



# TODO - grafana target for better testing
# grafana target

# See https://docs.aws.amazon.com/lambda/latest/dg/images-test.html
#rie:
#	@which aws-lambda-rie



