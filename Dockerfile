# See https://docs.aws.amazon.com/lambda/latest/dg/go-image.html#go-image-base

#FROM public.ecr.aws/lambda/provided:al2 as build
## install compiler
#RUN yum install -y golang
#RUN go env -w GOPROXY=direct
## cache dependencies
#ADD go.mod go.sum ./
#RUN go mod download
## build
#ADD . .
#RUN go build -o /main
## copy artifacts to a clean image
#FROM public.ecr.aws/lambda/provided:al2
#COPY --from=build /main /main
#ENTRYPOINT [ "/main" ]
#FROM golang:${GO_VERSION}-alpine as build
FROM alpine as build


# install build tools
ARG GO_VERSION=1.18
RUN apk update && apk add go~${GO_VERSION} git
RUN go env -w GOPROXY=direct
# cache dependencies
ADD go.mod go.sum ./
RUN go mod download
# build
ADD . .
RUN go build -o /main
# copy artifacts to a clean image
FROM alpine
COPY --from=build /main /main
ENTRYPOINT [ "/main" ]