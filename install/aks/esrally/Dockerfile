FROM ubuntu:18.04

# docker build -t david62243/esrally:v0.1 .

RUN apt-get update && \
    apt-get -y install gcc python3-pip python3-dev git openjdk-8-jre tmux curl vim

ENV JAVA_HOME /usr/lib/jvm/open-jdk

RUN pip3 install esrally 

EXPOSE 8001/tcp

WORKDIR /root
