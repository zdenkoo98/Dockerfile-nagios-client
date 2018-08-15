#image
FROM centos
#rpm epel
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm 
#Installation of packages 
RUN yum -y install httpd php gcc glibc glibc-common wget perl gd gd-devel unzip zip make openssh-server telnet net-tools curl
RUN yum install -y nrpe nagios-plugins-all
#add nagios-server to allowed hosts
WORKDIR /etc/nagios
RUN sed -i 's+allowed_hosts=127.0.0.1+allowed_hosts=127.0.0.1,prueba_nagios-server_1+g' nrpe.cfg
#SSH
RUN mkdir /var/run/sshd
RUN echo 'root:rootpasswd' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN echo "export VISIBLE=now" >> /etc/profile
RUN /usr/bin/ssh-keygen -A
RUN /usr/sbin/sshd

#TEST
ENV NAGIOS_CONF_DIR /etc/nagios
ENV NAGIOS_PLUGINS_DIR /usr/lib/nagios/plugins

#RUN sed -e 's/^allowed_hosts=/#allowed_hosts=/' -i $NAGIOS_CONF_DIR/nrpe.cfg \
#    && echo "command[check_load]=$NAGIOS_PLUGINS_DIR/check_load -w 15,10,5 -c 30,25,20" > $NAGIOS_CONF_DIR/nrpe.d/load.cfg \
#    && echo "command[check_mem]=$NAGIOS_PLUGINS_DIR/check_mem -f -C -w 12 -c 10 " > $NAGIOS_CONF_DIR/nrpe.d/mem.cfg \
#    && echo "command[check_total_procs]=/usr/lib/nagios/plugins/check_procs -w 500 -c 700 " > $NAGIOS_CONF_DIR/nrpe.d/procs.cfg

#download dumb-init (process 1)
RUN curl -o /usr/local/bin/dumb-init -L https://github.com/Yelp/dumb-init/releases/download/v1.0.0/dumb-init_1.0.0_amd64 && \
   chmod +x /usr/local/bin/dumb-init


ENV ETCDCTL_VERSION v2.2.5
RUN curl -L https://github.com/coreos/etcd/releases/download/$ETCDCTL_VERSION/etcd-$ETCDCTL_VERSION-linux-amd64.tar.gz -o /tmp/etcd-$ETCDCTL_VERSION-linux-amd64.tar.gz && \
    cd /tmp && gzip -dc etcd-$ETCDCTL_VERSION-linux-amd64.tar.gz | tar -xof - && \
    cp -f /tmp/etcd-$ETCDCTL_VERSION-linux-amd64/etcdctl /usr/local/bin && \
    rm -rf /tmp/etcd-$ETCDCTL_VERSION-linux-amd64.tar.gz

#nrpe.sh (script to start nrpe)
ADD run-nrpe.sh /usr/sbin/run-nrpe.sh
RUN chmod +x /usr/sbin/run-nrpe.sh

ADD plugins $NAGIOS_PLUGINS_DIR
RUN chmod +x -R  $NAGIOS_PLUGINS_DIR

ADD nrpe.d $NAGIOS_CONF_DIR/nrpe.d

#Run apache
RUN /sbin/apachectl -D BACKGROUND
#Apache index creation
RUN touch /var/www/html/index.html
RUN chmod 755 /var/www/html/index.html
#Ports to expose (ssh, http and NRPE)
EXPOSE 22 80 5666

CMD ["/usr/local/bin/dumb-init", "/usr/sbin/run-nrpe.sh"]
