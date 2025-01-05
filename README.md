# Runner

Docker to run after all your other dockers to perform tasks with a script.sh

## Example usage docker_compose.ytml

 runner:
    container_name: runner
    image: "myridia/runner"
    depends_on:
      - db
      - web
    volumes:
      - ./runner.sh:/runner.sh
    networks:
      workgroup:
          ipv4_address: "10.5.0.5"
    entrypoint: ["/bin/bash", "/runner.sh"]


## Example runner.sh, script what get loaded into the runner docker to perform all the tasks needed

In this particular example, its wating until the connection to the postgres db is read. Afert
its connect to the db and executed a delete query. In this case to delete all Odoo's ir_attachedment to force a recreation.


#!/bin/bash
#cd /var/www/html/

echo "...docker runner is running..."
echo "...checking if the Postgres database is ready for connections"
while !  pg_isready -h 10.5.0.3; do
   echo "...sleep 1s until database docker server is up and ready..."
   sleep 1
done

echo "...Postgres Database is ready, now trying to clean up ir_attachment table"
export PGPASSWORD=YOURPASSWORD
psql -h db -U odoo odoo -c  "delete from ir_attachment where res_model='ir.ui.view' and name like '%assets_%';"


