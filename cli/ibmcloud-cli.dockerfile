FROM ubuntu:19.10
LABEL image.name="ibmcloud/cli" \
      image.version="0.1" \
      image.author="sharon.dagan@il.ibm.com"

# Notes about latest releases
# terraform latest release: https://releases.hashicorp.com/terraform/
# ibmcloud terraform provider latest release: https://github.com/IBM-Cloud/terraform-provider-ibm/releases/latest

ENV ARCH                       amd64
ENV TERRAFORM_VERSION          0.12.24
ENV IBMCLOUD_TERRAFORM_VERSION 1.3.0

RUN apt update \
      && apt install -y curl git vim mc iputils-ping python3 python3-pip ruby2.5-dev \
      && apt install -y apt-utils apt-transport-https ca-certificates software-properties-common \
      && gem install --no-document docopt \
      && echo 'IRB.conf[ :AUTO_INDENT ] = true                                      \n\
               IRB.conf[ :USE_READLINE ] = true                                     \n\
               IRB.conf[ :LOAD_MODULES ] = [] unless IRB.conf.key?( :LOAD_MODULES ) \n\
               unless IRB.conf[ :LOAD_MODULES ].include?( "irb/completion" )        \n\
                 IRB.conf[ :LOAD_MODULES ] << "irb/completion"                      \n\
               end ' > ~/.irbrc

WORKDIR /tmp

# install terraform
RUN curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip \
      && unzip terraform*.zip \
      && mv terraform /usr/local/bin \
      && echo 'complete -C /usr/local/bin/terraform terraform' >> /root/.bashrc \
      && rm -rf /tmp/*

# install ibm cloud terraform provider
RUN curl -LO https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v${IBMCLOUD_TERRAFORM_VERSION}/linux_${ARCH}.zip \
      && unzip linux_*.zip \
      && mkdir -p ${HOME}/.terraform.d/plugins \
      && mv terraform-provider-ibm* ${HOME}/.terraform.d/plugins \
      && rm -rf /tmp/*

# install the latest ibm cloud cli release and supporting plugins
RUN curl -sL https://ibm.biz/idt-installer | bash
RUN ibmcloud cf install \
      && echo "vpc-infrastructure cis doi tke vpn cloud-dns-services cloud-databases analytics-engine machine-learning power-iaas" | xargs -n 1 ibmcloud plugin install \
      && echo 'source /usr/local/ibmcloud/autocomplete/bash_autocomplete' >> /root/.bashrc

ENV IBMCLOUD_COLOR true
WORKDIR /cwd
