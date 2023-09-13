# wordpress-podman
Scripts to create, manage and backup Wordpress on Podman.

## wp-create.sh
This is a script that will create a pod, 3 containers, 3 volumes and a secret.
The secret is a randomly generated database password.
The default pod name is *blog*, otherwise the first argument passed will be used.
The three containers are
- *blog*-fpm (`docker.io/library/wordpress:fpm-alpine`)
  - access to the secret
  - a volume mounted at `/var/www/html` which will contain the wordpress content
- *blog*-db (`docker.io/library/mariadb:latest`)
  - access to the secret
  - a volume mounted at `/var/lib/mysql` which will contain the database files
- *blog*-nginx (`docker.io/library/nginx:alpine`)
  - a volume mounted at `/etc/nginx/conf.d` which contains nginx configuration snippets
  - a volume mounted at `/var/www/html` which is the same as mounted on *blog*-fpm
  - a minimal nginx config snippet will be written to `/etc/nginx/conf.d/blog.conf`

At present, we don't automatically publish a port since this would conflict if you were running multiple pods. However, removing the [commented which stops the `--publish` entry being run](https://github.com/guest42069/wordpress-podman/blob/main/wp-create.sh#L26) is a relatively simple task.

_WARNING_: It is [relatively common for Wordpress sites in a newly deployed state awaiting installation are hijacked](https://www.wordfence.com/blog/2017/07/hackers-find-wordpress-within-30-mins/) and used to serve spam or malicious content or worse. As such, you may wish to expose the port and put the site online only after the setup is complete.

In the following examples, the pod name of *test* was used.

```
# ./wp-create.sh test

# podman pod stats test --no-stream
POD           CID           NAME                CPU %       MEM USAGE/ LIMIT   MEM %       NET IO       BLOCK IO          PIDS
ad773fcfa3aa  fbd59ee5cc50  ad773fcfa3aa-infra  0.03%       45.06kB / 8.205GB  0.00%       664B / 790B  -- / --           1
ad773fcfa3aa  1bdf4bb1b1bd  test-fpm            4.22%       5.784MB / 8.205GB  0.07%       664B / 790B  0B / 75.5MB       3
ad773fcfa3aa  cfe00e63e94f  test-db             14.51%      80.4MB / 8.205GB   0.98%       664B / 790B  9.798MB / 47.3MB  13
ad773fcfa3aa  ece637f7f309  test-nginx          0.14%       3.531MB / 8.205GB  0.04%       664B / 790B  0B / 4.096kB      5

# curl -I http://`podman inspect -f '{{.NetworkSettings.IPAddress}}' test-nginx`/
HTTP/1.1 302 Found
Server: nginx
Date: Wed, 13 Sep 2023 08:20:17 GMT
Content-Type: text/html; charset=UTF-8
Connection: keep-alive
X-Powered-By: PHP/8.0.30
Expires: Wed, 11 Jan 1984 05:00:00 GMT
Cache-Control: no-cache, must-revalidate, max-age=0
X-Redirect-By: WordPress
Location: http://10.89.0.10/wp-admin/install.php
```

To have the pod and containers start automatically, I recommend using podman's generated systemd service files.

```
cd /etc/systemd/system
podman generate systemd --new --name --files test
systemctl enable --now pod-test
```

The pod and containers can now be started and stopped as regular services.

```
# e.g.
systemctl restart pod-test
# or
systemctl restart container-test-nginx
# or
systemctl disable --now pod-test
```

## wp-mgmt.sh
This script will create a new container in the specified pod (the default is *blog*) and you will be dropped into a command line inside the container.
The container is as follows
- `docker.io/library/wordpress:cli`
  - access to the secret
  - a volume mounted at `/var/www/html` which is the same as mounted on *blog*-fpm
The wordpress cli tool can be used for maintenance and house keeping, it can be run with the `wp` command.

```
# ./wp-mgmt.sh
bash-5.1$ wp core verify-checksums
Warning: File should not exist: wp-config-docker.php
Success: WordPress installation verifies against checksums.
bash-5.1$ wp core check-update
Success: WordPress is at the latest version.
bash-5.1$ wp plugin update --all
Success: Plugin already updated.
bash-5.1$ wp theme update --all
Success: Theme already updated.
bash-5.1$ exit
```

## wp-backup.sh
This script will create a gzip'd tarball archive file named `blog-backup.tgz` in the current directory.
The archive will contain two files, one `blog-var-www-html.tar` which containers the wordpress content and the other `blog-db.sql` which is a dump of the wordpress database for *blog*.
The first argument passed to the script should be the name of the pod you're backing up. The *blog* part of the filename will match your pods name.

```
# ./wp-backup.sh
# tar vtaf blog-backup.tgz
-rw-r--r-- root/root   1326009 2023-09-13 08:44 blog-db.sql
-rw-r--r-- root/root  97610240 2023-09-13 08:44 blog-var-www-html.tar
```

It should be noted when restoring, the .tar file is in the format of a podman exported volume and as such restoring it can by creating a volume, and importing the tar to the newly created volume.

```
# tar zxf blog-backup.tgz
# podman volume create blog-var-www-html
# podman volume import blog-var-www-html ./blog-var-www-html.tar
# ls `podman volume inspect -f '{{.Mountpoint}}' blog-var-www-html`
index.php    readme.html      wp-admin            wp-comments-post.php  wp-config-sample.php  wp-content   wp-includes        wp-load.php   wp-mail.php      wp-signup.php     xmlrpc.php
license.txt  wp-activate.php  wp-blog-header.php  wp-config-docker.php  wp-config.php         wp-cron.php  wp-links-opml.php  wp-login.php  wp-settings.php  wp-trackback.php
```

And to restore the database from the .sql file

```
# PASSWORD=`podman exec "blog-db" cat "/run/secrets/blog-mysql-root"`
# podman exec -i blog-db mariadb -u root --password=${PASSWORD} < blog-db.sql
```

I may add a wp-restore.sh eventually to automate recreating and restoring, but simply running create again followed by the above steps should suffice and would also be suitable for migrations.
