FROM ubuntu:19.10
LABEL image.name="ibmcloud/cli" \
      image.version="0.1" \
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
ENV TERRAFORM_VERSION 0.12.24
RUN curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
      && unzip terraform*.zip \
      && mv terraform /usr/local/bin \
      && echo 'complete -C /usr/local/bin/terraform terraform' >> /root/.bashrc \
      && rm -rf /tmp/*

# install the latest ibm cloud terraform provider
RUN latest_release=$(curl -sS https://api.github.com/repos/IBM-Cloud/terraform-provider-ibm/releases/latest | grep browser_download_url | awk -F '"' '/linux_amd64.zip/{print $4}') \
      && curl -o /tmp/ibmcloud_terraform_provider_latest.zip -L ${latest_release} \
      && unzip ibmcloud_terraform_provider_latest.zip \
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
