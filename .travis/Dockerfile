FROM dracoblue/nginx-extras:1.10.1-3
RUN apt-get update
RUN apt-get install lua-cjson lua-lpeg
RUN apt-get install lua5.1
ADD .travis/port-4777-app.conf /etc/nginx/sites-enabled/port-4777-app.conf
ADD .travis/port-4778-app.conf /etc/nginx/sites-enabled/port-4778-app.conf
EXPOSE 4778
EXPOSE 4777
