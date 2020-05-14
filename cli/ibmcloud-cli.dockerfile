FROM ubuntu:19.10

ENV TERRAFORM_VERSION                   0.12.24
ENV IBMCLOUD_CLI_VERSION                LATEST
ENV IBMCLOUD_TERRAFORM_PROVIDER_VERSION LATEST

LABEL image.name="ibmcloud/cli" \
      image.version="${IBMCLOUD_TERRAFORM_PROVIDER_VERSION}" \
      image.author="sharon.dagan@il.ibm.com"

RUN apt update \
      && apt install -y curl git vim mc iputils-ping netcat python3 python3-pip ruby2.5-dev \
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
RUN curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
      && unzip terraform*.zip \
      && mv terraform /usr/local/bin \
      && echo 'complete -C /usr/local/bin/terraform terraform' >> /root/.bashrc \
      && rm -rf /tmp/*

# install the latest ibm cloud terraform provider
RUN if [ "${IBMCLOUD_TERRAFORM_PROVIDER_VERSION}" = "LATEST" ]; then IBMCLOUD_TERRAFORM_PROVIDER_VERSION=$(curl -sS https://api.github.com/repos/IBM-Cloud/terraform-provider-ibm/releases/latest | awk -F '"' '/tag_name/{print(substr($4,2))}') ; fi \
      && curl -o /tmp/ibmcloud_terraform_provider.zip -L https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v${IBMCLOUD_TERRAFORM_PROVIDER_VERSION}/linux_amd64.zip \
      && unzip ibmcloud_terraform_provider.zip \
      && mkdir -p ${HOME}/.terraform.d/plugins \
      && mv terraform-provider-ibm* ${HOME}/.terraform.d/plugins \
      && rm -rf /tmp/*

# install the latest ibm cloud cli release and supporting plugins
RUN curl -sL https://ibm.biz/idt-installer | bash
RUN ibmcloud cf install \
      && ibmcloud plugin repo-plugins | awk '/Not Installed/{print $3}' | awk -F '/' '{print $1}' | xargs -n 1 ibmcloud plugin install || true \
      && echo 'source /usr/local/ibmcloud/autocomplete/bash_autocomplete' >> /root/.bashrc

ENV IBMCLOUD_COLOR true
WORKDIR /cwd
