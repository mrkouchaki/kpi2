# FROM ubuntu:18.04
#FROM nexus3.o-ran-sc.org:10002/o-ran-sc/bldr-ubuntu18-c-go:1.9.0 as build-kpimon
FROM nexus3.o-ran-sc.org:10004/o-ran-sc/bldr-ubuntu20-c-go:1.0.0 as kpimonbuild

WORKDIR /opt
# Install RMR client

ENV RMR_SEED_RT /opt/routes.txt
COPY routes.txt /opt/routes.txt
ARG RMRVERSION=4.0.2
ARG RMRLIBURL=https://packagecloud.io/o-ran-sc/release/packages/debian/stretch/rmr_${RMRVERSION}_amd64.deb/download.deb
ARG RMRDEVURL=https://packagecloud.io/o-ran-sc/release/packages/debian/stretch/rmr-dev_${RMRVERSION}_amd64.deb/download.deb
RUN wget --content-disposition ${RMRLIBURL} && dpkg -i rmr_${RMRVERSION}_amd64.deb
RUN wget --content-disposition ${RMRDEVURL} && dpkg -i rmr-dev_${RMRVERSION}_amd64.deb
RUN rm -f rmr_${RMRVERSION}_amd64.deb rmr-dev_${RMRVERSION}_amd64.deb


WORKDIR /opt
ARG XAPPFRAMEVERSION=v0.4.11
#WORKDIR /go/src/gerrit.o-ran-sc.org/r/ric-plt
# RUN git clone "https://gerrit.o-ran-sc.org/r/ric-plt/sdlgo"
RUN git clone -b ${XAPPFRAMEVERSION} "https://gerrit.o-ran-sc.org/r/ric-plt/xapp-frame"
RUN cd xapp-frame && \
   GO111MODULE=on go mod vendor -v && \
    cp -r vendor/* ./ && \
    rm -rf vendor



#COPY bin/rmr* ./
#RUN dpkg -i rmr_4.8.0_amd64.deb; dpkg -i rmr-dev_4.8.0_amd64.deb; rm rmr*
RUN apt-get update && \
    apt-get -y install gcc
COPY e2ap/ e2ap/
COPY e2sm/ e2sm/
# "COMPILING E2AP Wrapper"
RUN cd e2ap && \
    gcc -c -fPIC -Iheaders/ lib/*.c wrapper.c && \
    gcc *.o -shared -o libe2apwrapper.so && \
    cp libe2apwrapper.so /usr/local/lib/ && \
    mkdir /usr/local/include/e2ap && \
    cp wrapper.h headers/*.h /usr/local/include/e2ap && \
    ldconfig

# "COMPILING E2SM Wrapper"
RUN cd e2sm && \
    gcc -c -fPIC -Iheaders/ lib/*.c wrapper.c && \
    gcc *.o -shared -o libe2smwrapper.so && \
    cp libe2smwrapper.so /usr/local/lib/ && \
    mkdir /usr/local/include/e2sm && \
    cp wrapper.h headers/*.h /usr/local/include/e2sm && \
    ldconfig
# Setup running environment
COPY control/ control/
COPY ./go.mod ./go.mod
COPY ./kpimon.go ./kpimon.go

RUN wget -nv --no-check-certificate https://dl.google.com/go/go1.18.linux-amd64.tar.gz \
     && tar -xf go1.18.linux-amd64.tar.gz \
     && rm -f go*.gz
ENV DEFAULTPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV PATH=$DEFAULTPATH:/usr/local/go/bin:/opt/go/bin:/root/go/bin
COPY go.sum go.sum

RUN pwd
RUN go mod download

COPY . .

RUN pwd
RUN go env -w GO111MODULE=off && \ (pwd)
RUN go build ./kpimon.go
#&& pwd && ls -lat

#RUN go build ./kpimon.go

COPY config-file.yaml .
ENV CFG_FILE=/opt/config-file.yaml
COPY routes.txt .
ENV RMR_SEED_RT=/opt/routes.txt

ENTRYPOINT ["env","LD_LIBRARY_PATH=/usr/local/lib","./kpimon"]
