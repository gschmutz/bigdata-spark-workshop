# AWS Lightsail

Navigate to the [AWS Console](http://console.aws.amazon.com) and login with your user. Click on the [Lightsail service](https://lightsail.aws.amazon.com/ls/webapp/home/instances).

![Alt Image Text](./images/lightsail-homepage.png "Lightsail Homepage")

## Provision instance

Click **Create instance** to navigate to the **Create an instance** dialog. 

![Alt Image Text](./images/lightsail-create-instance-1.png "Lightsail Homepage")

Optionally change the **Instance Location** to a AWS region of your liking.
Keep **Linux/Unix** for the **Select a platform** and click on **OS Only** and select **Ubuntu 18.04 LTS** for the **Select a blueprint**. 

![Alt Image Text](./images/lightsail-create-instance-2.png "Lightsail Homepage")

Scroll down to **Launch script** and add the following script 

```
# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable edge"
apt-get install -y docker-ce
sudo usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Prepare Environment Variables
export PUBLIC_IP=$(curl ipinfo.io/ip)
export DOCKER_HOST_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

# needed for elasticsearch
sudo sysctl -w vm.max_map_count=262144   

# Get the project
cd /home/ubuntu 
git clone https://github.com/gschmutz/hadoop-spark-workshop.git
chown -R ubuntu:ubuntu hadoop-spark-workshop

cd hadoop-spark-workshop/01-environment/docker-minio

# Get sample flight data
cd data-transfer
mkdir -p flight-data
cd flight-data
wget https://gschmutz-datasets.s3.eu-central-1.amazonaws.com/datasets/flight-data.zip
unzip -o flight-data.zip
rm flight-data.zip
rm -R __MACOSX/

cd hadoop-spark-workshop/01-environment/docker-minio
# Startup Environment
sudo -E docker-compose up -d
```

into the **Launch Script** edit field
 
![Alt Image Text](./images/lightsail-create-instance-3.png "Lightsail Homepage")

Click on **Change SSH key pair** and leave the **Default** selected and then click on **Download** and save the file to a convenient location on your machine. Under **Choose your instance plan** click on the arrow on the right and select the **16 GB** instance.   

Under **Identify your instance** enter **Ubuntu-Hadoop-1** into the edit field. 

![Alt Image Text](./images/lightsail-create-instance-4.png "Lightsail Homepage")

Click on **Create Instance** to start provisioning the instance. 

The new instance will show up in the Instances list on the Lightsail homepage. 

![Alt Image Text](./images/lightsail-image-started.png "Lightsail Homepage")

Click on the instance to navigate to the image details page. On the right you can find the Public IP address **18.196.124.212** of the newly created instance.

![Alt Image Text](./images/lightsail-image-details.png "Lightsail Homepage")

Click **Connect using SSH** to open the console and enter the following command to watch the log file of the init script.

```
tail -f /var/log/cloud-init-output.log --lines 1000
```

The initialisation is finished when you see the `Creating xxxxx .... done` lines after all the docker images have been downloaded, which takes a couple of minutes. 

![Alt Image Text](./images/lightsail-create-instance-log-file.png "Lightsail Homepage")

Optionally you can also SSH into the Lightsail instance using the **SSH key pair** you have downloaded above. For that open a terminal window (on Mac / Linux) or Putty (on Windows) and connect as ubuntu to the Public IP address of the instance.   

```
ssh -i LightsailDefaultKey-eu-central-1.pem ubuntu@18.196.124.212 
```

## Connecting to Services from Client

For accessing the services in the cloud, we have to options:
  * use a SSH Tunnel
  * open the ports on the firewall

Due to the fact, that the lightsail instance is exposed to the public internet, opening the ports is not the best idea. Using an SSH tunnel is much more secure.  

### SSH Tunnel as a Socks Proxy

Opening an SSH tunnel is different on Windows and Mac. The following short description shows how to create the tunnel on Windows and on Mac OS-X.

#### Using Windows

First you have to install Putty (available at <http://www.chiark.greenend.org.uk/~sgtatham/putty/>). We will use Putty to extract the private key as well as for creating the SSH Tunnel. 

**1. Download the SSH Key of the Lightroom instance and Extract Private Key**

In order to connect to the lightsail instance, a copy of the private SSH key. You can use the key pair that Lightsail creates. Download the key from the AWS console by choosing **Account** on the top navigation bar and again choose **Account** from the drop-down menu. Navigate to the **SSH Keys** tab. 

![Alt Image Text](./images/ssh-keys-download.png "Lightsail Homepage")

Select the **Default** key and click on the **Download** link to download it to your local computer. 

Now start the **PuTTYgen** tool you have installed before. The following screen should appear. 

![Alt Image Text](./images/putty-gen-1.png "Lightsail Homepage")

Click on **Load** and load the `xxxxxxx.pem` file you have downloaded before. By default, PuTTYgen displays only files with the `.ppk` extension. To locate your `.pem` file, select the option to display files of all types.

PuTTYgen confirms that you successfully imported the key, and then you can choose OK.

Choose **Save private key**, and then confirm you don't want to save it with a passphrase.

**2. Create the SSH Tunnel**

Start Putty and from the Session tab, enter the public IP (54.93.82.199) into the **Host Name (or IP address)** field. Leave the **port** field to 22.

![Alt Image Text](./images/putty-1.png "Lightsail Homepage")

Now click on the **SSH** folder, expand it and click on **Auth**. 

![Alt Image Text](./images/putty-2.png "Lightsail Homepage")

Click on **Browse** and select the private key file you have created above.  

Click on **Tunnels** and on the screen, enter `9870` into the **Source port** field, click the **Dynamic** radio button and then click on **Add**.

![Alt Image Text](./images/putty-3.png "Lightsail Homepage")

Now click on **Open** and confirm the Alert pop up with **Yes**. Enter `ubuntu` as the login user and you should get the bash prompt. 

Be sure to save your connection for future use.

**3. Configure Web Browser to use the SSH Tunnel** 

As a last step you have to configure the browser (we assume Firefox here, but Chrome would be fine as well) to use the SSH Tunnel. 

Install the **FoxyProxy Standard** extension into Firefox. 

![Alt Image Text](./images/firefox-addon.png "Lightsail Homepage")

After installing the Addon, click on the new icon in the top right corner of the menu bar and click on **Options**. 

![Alt Image Text](./images/firefox-foxyproxy-1.png "Lightsail Homepage")

Click on **Add** in the menu to the left. Configure the proxy settings as shown below

![Alt Image Text](./images/firefox-foxyproxy-2.png "Lightsail Homepage")

and click **Save**. 
Click again on the **FoxyProxy** icon in the top right corner and select the **Hadoop Workshop** entry to enable the proxy settings. 

![Alt Image Text](./images/firefox-foxyproxy-3.png "Lightsail Homepage")

You can now reach the services on Lightsail using the localhost address. For example you can reach Zeppelin over <http://localhost:38081>. For the other URLs, consult the table at the bottom of the main [Readme](README.md). 

#### Using Mac OS-X

**1. Download the SSH Key of the Lightroom instance**

Download the key from the AWS console by choosing **Account** on the top navigation bar and again choose **Account** from the drop-down menu. Navigate to the **SSH Keys** tab. 

![Alt Image Text](./images/ssh-keys-download.png "Lightsail Homepage")

Select the **Default** key and click on the **Download** link to download it to your local computer. 

**2. Create the SSH Tunnel**
On Mac OS-X you can either use the `ssh` command line utility to open up a ssh tunnel or 
download an SSH Tunnel GUI client. The [**Secure Pipes**](https://www.opoet.com/pyro/) Application is the one I use here.

To configure Secure Pipes, click on the cloud icon in the menu bar

![Alt Image Text](./images/secure-pipes-0.png "Lightsail Homepage")

and select the **Preferences** menu. The **Connections** overview screen is shown. 

![Alt Image Text](./images/secure-pipes-1.png "Lightsail Homepage")

Click on the **+** icon in the bottom left corner and select **New SOCKS Proxy...** from the drop-down menu. 

On the **Connection** tab, enter `Hadoop Workshop` into the **Connection Name** field and use the public IP address of the Lightsail instance for the **SSH Server Address** field. Set the **Port** field to `22`, **Local Bind Address** field to `localhost` and the other **Port** field to a port which is not used on your local computer. 
If you have administrator rights on your Mac, then you can enable the **Automatically configure SOCKS proxy in Network Preferences** as shown below. 

![Alt Image Text](./images/secure-pipes-2.png "Lightsail Homepage")

Next click on **Options** and enable the **Use ssh identity file** check box and click on **Select...** to select the key file you have downloaded in step 1. 

![Alt Image Text](./images/secure-pipes-3.png "Lightsail Homepage")

Click **Add** to add the new connection to the **Secure Pipes**. 

Now the SSH tunnel can be activated by again clicking on the clod icon in the menu bar and selecting the connection **Hadoop Workshop** configured above.

![Alt Image Text](./images/secure-pipes-4.png "Lightsail Homepage")

The green icon in front of the connection signals that the SSH tunnel has been established successfully. 

**3. Configure Web Browser to use the SSH Tunnel** 

As a last step you have to configure the browser (we assume Firefox here, but Chrome would be fine as well) to use the SSH Tunnel. 

Install the **FoxyProxy Standard** extension into Firefox. 

![Alt Image Text](./images/firefox-addon.png "Lightsail Homepage")

After installing the Addon, click on the new icon in the top right corner of the menu bar and click on **Options**. 

![Alt Image Text](./images/mac-firefox-foxyproxy-1.png "Lightsail Homepage")

Click on **Add** in the menu to the left. Configure the proxy settings as shown below

![Alt Image Text](./images/mac-firefox-foxyproxy-2.png "Lightsail Homepage")

and click **Save**. 

Click again on the **FoxyProxy** icon in the top right corner and select the **Hadoop Workshop** entry to enable the proxy settings. 

![Alt Image Text](./images/mac-firefox-foxyproxy-3.png "Lightsail Homepage")

You can now reach the services on Lightsail using the localhost address. For example you can reach Zeppelin over <http://localhost:38081>. For the other URLs, consult the table at the bottom of the main [Readme](README.md). 


### Open Ports on Firewall

So with all services running, there is one last step to do. We have to configure the Firewall to allow traffic into the Lightsail instance. 

![Alt Image Text](./images/lightsail-image-networking.png "Lightsail Homepage")

Click on the **Networking** tab/link to navigate to the network settings and under **Firewall** click on ** **Add another**.
For simplicity reasons, we allow all TCP traffic by selecting **All TCP** on port range **0 - 65535** and then click **Save**. 

![Alt Image Text](./images/lightsail-image-networking-add-firewall-rule.png "Lightsail Homepage")

Your instance is now ready to use. Complete the post installation steps documented the [here](README.md).

## Stop an Instance

To stop the instance, navigate to the instance overview and click on the drop-down menu and select **Stop**. 

![Alt Image Text](./images/lightsail-stop-instance.png "Lightsail Homepage")

Click on **Stop** to confirm stopping the instance. 

![Alt Image Text](./images/lightsail-stop-instance-confirm.png "Lightsail Homepage")

A stopped instance will still incur charges, you have to delete the instance completely to stop charges. 

## Delete an Instance

t.b.d.

## Create a snapshot of an Instance

When an instance is stopped, you can create a snapshot, which you can keep, even if later drop the instance to reduce costs.

![Alt Image Text](./images/lightsail-image-create-snapshot.png "Lightsail Homepage")

You can always recreate an instance based on a snapshot. 

# De-provision the environment

To stop the environment, execute the following command:

```
docker-compose stop
```

after that it can be re-started using `docker-compose start`.

To stop and remove all running container, execute the following command:

```
docker-compose down
```

