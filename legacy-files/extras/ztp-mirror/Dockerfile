FROM registry.access.redhat.com/ubi8/python-38:1-96

RUN mkdir -p /tmp/server/pub/openshift-v4/x86_64/dependencies/rhcos/
RUN mkdir -p /tmp/server/config/

COPY container-root /

CMD /start.sh