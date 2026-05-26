FROM debian:latest
LABEL version="0.1"
MAINTAINER veto<veto@myridia.com>
RUN apt-get update -y && apt-get install -y \
  apt-transport-https \ 
  lsb-release \
  ca-certificates \
  curl \
  wget \	      
  apt-utils \
  openssh-server \
  default-mysql-client \
  gcc \
  make \
  emacs-nox \ 
  vim \ 
  git \
  gnupg \
  unzip \
  p7zip-full \
  postgresql-client \
  inetutils-ping  \
  net-tools \
  git \
  nodejs \
  npm \
  tree \
  pipx 


CMD ["echo", "Hello Runner..."]
