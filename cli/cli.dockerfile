FROM ubuntu:19.10

ENV ARCH amd64

ENV IBMCLOUD_CLI_VERSION       0.21.1
ENV IBMCLOUD_TERRAFORM_VERSION 1.2.5
ENV TERRAFORM_VERSION          0.12.24
ENV DOCKER_CLI_VERSION         19.03.5
ENV KUBECTL_VERSION            1.17.1
ENV HELM_VERSION               2.16.1

RUN apt update \
      && apt install -y curl git vim mc

WORKDIR /tmp

# install terraform
RUN curl -L -o file.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip \
      && unzip file.zip \
      && mv terraform /usr/local/bin \
      && rm -rf /tmp/*

# install ibm cloud terraform provider
RUN curl -L -o file.zip https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v${IBMCLOUD_TERRAFORM_VERSION}/linux_${ARCH}.zip \
      && unzip file.zip \
      && mkdir -p ${HOME}/.terraform.d/plugins \
      && mv terraform-provider-ibm* ${HOME}/.terraform.d/plugins \
      && rm -rf /tmp/*

# install ibm cloud cli and supporting tools
RUN curl -sL https://ibm.biz/idt-installer | bash
RUN echo "vpc-infrastructure power-iaas tke analytics-engine doi cloud-databases machine-learning" | xargs -n 1 ibmcloud plugin install

WORKDIR /root
ENV IBMCLOUD_COLOR true
