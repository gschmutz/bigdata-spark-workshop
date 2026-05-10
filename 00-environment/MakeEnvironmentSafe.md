# Fix issue with AWS Ligthsail instances

Several of you have received an AWS abuse report. It's still not 100% clear to me why this happens, it is definitely not caused by a service started by me / us (from inside the docker-compose) but from someone using the environment as a "jump server" to do this attacks. 

I believe that the security whole was due to the `zeppelin` service not needing a password. This has been fixed last week, if you upgrade to the latest docker-compose definition. 
Additionally we can further close down the instance by no longer allowing all TCP traffic over the firewall but using a TCP tunnel with port forwarding. 

## Update to latest version of docker-compose

Either freshly create a new Lightsail instance (be aware that all data will be lost) or update the current instance and restart the relevant containers.

#### Create a fresh environment

Follow again [these instructions](Lightsail.md).

### Update 
  
Connect to the Lightsail instance through **Connect Using SSH** on the Ligthsail console or using the `ssh`command (Mac) / Putty (Windows). 

```
cd hadoop-workshop/01-environment/docker
```

```
git pull
```

```
docker-compose stop streamsets
docker-compose stop zeppelin

docker-compse rm streamsets
docker-compse rm zeppelin

docker-compose up -d
```

## Switch to SSH tunnel instead of allowing all traffic through the firewall

Follow the [instructions](Lightsail.md) about "Connecting to Services from Client".  

After that you have to remove the **All TCP** firewall rule. In AWS Lightsaill console, navigate to your instance and to the **Networking** tab.
Click **Edit rules** and remove the **All TCP** line by clicking on the **X** to the right. This removes the rule. Before saving the changes, add a new rule to allow SSH. 
Click **Add rule** and from the **Application** drop-down select `SSH` and then click **Save**. 

You should now have only one rule allowing traffic on Port 22.





