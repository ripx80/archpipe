FROM archlinux/base
COPY buildBase.sh /init.sh
RUN chmod +x /init.sh
ENTRYPOINT [ "./init.sh" ]
#VOLUME ["/artefacts"]
# if you run it with volume then you canot use --rm
#docker run -it --privileged ripx80/archbase
#docker run --rm -it -v $(pwd)/artefacts:/artefacts --privileged ripx80/archbase
#docker build -t ripx80/archbase:latest .
#docker import arch-base-2019-07-12.tar.gz rip/archsystem:latest