# Data Ingestion with Apache NiFi

In this workshop we will see how we can use [Apache NiFi](http://nifi.apache.org) to ingest the flight data automatically into S3 object storage. It shows the usage of Apache NiFi for Batch-Data (delta) ingestion, refer to the Streaming Workshop for a workshop where Apache NiFi is used in a Stream-Data Ingestion.

## Create the Bucket in S3

For this workshop we will use a new bucket, separate from the other workshops. Use the following command to create the `flight-nifi-bucket`.

```bash
docker exec -ti minio-mc mc mb minio-1/flight-nifi-bucket
```

## Make sure that sub-folders below `data-transfer` belong to your local user (`$USER`)

In a terminal, navigate to the `data-transfer` folder. 

```bash
cd $DATAPLATFORM_HOME/data-transfer
```

We will use a folder `landing-zone` which we need to create

```bash
mkdir -p landing-zone
```

now perform a `chown` to change the owner of all subfolders

```bash
sudo chown $USER:$USER *
```

check that the folders are now under the right user

```bash
$ ls -lsa
4 drwxr-xr-x 16 ubuntu ubuntu 4096 May 29 20:39 .
4 drwxr-xr-x 15 ubuntu ubuntu 4096 May 29 19:41 ..
8 -rw-r--r--  1 ubuntu ubuntu 5472 May 22 11:55 00000000000000000000.json
8 -rw-r--r--  1 ubuntu ubuntu 4597 May 22 18:12 00000000000000000001.json
4 -rw-r--r--  1 ubuntu ubuntu 2893 May 22 18:18 00000000000000000002.json
4 drwxr-xr-x  2 ubuntu ubuntu 4096 May 29 19:46 adventureworks
4 drwxr-xr-x  2 ubuntu ubuntu 4096 May 29 19:46 airport-data
4 drwxrwxr-x  2 ubuntu ubuntu 4096 May 29 17:06 app
4 drwxr-xr-x  5 ubuntu ubuntu 4096 May 29 19:46 flight-data
4 drwxr-xr-x  2 ubuntu ubuntu 4096 May 29 19:46 graphdb-news
4 drwxr-xr-x  2 ubuntu ubuntu 4096 May 29 19:46 imdb-movies
4 drwxrwxr-x  2 ubuntu ubuntu 4096 May 29 20:39 landing-zone
4 drwxr-xr-x  4 ubuntu ubuntu 4096 May 20 19:58 movie-lens-small
4 drwxr-xr-x  2 ubuntu ubuntu 4096 May 29 19:46 nyc-film-permits
4 drwxr-xr-x  2 ubuntu ubuntu 4096 May 29 19:46 orion-star
4 drwxr-xr-x  3 ubuntu ubuntu 4096 May 20 19:58 platys-cookbooks
4 -rw-r--r--  1 ubuntu ubuntu   59 May 20 19:47 readme.txt
4 drwxr-xr-x  4 ubuntu ubuntu 4096 May 22 11:37 result
4 drwxr-xr-x  2 ubuntu ubuntu 4096 May 20 19:47 synthetic-load-generator
4 drwxr-xr-x  2 ubuntu ubuntu 4096 May 29 19:46 wordcount
```

## Create the Nifi data flow

In a browser navigate to <https://dataplatform:18083/nifi> (make sure to replace `dataplatform` by the IP address of the machine where docker runs on,). We have enabled authentication for NiFi, therefore you have to use https to access it. Due to the use of a self-signed certificate, you have to initially confirm that the page is safe and you want to access the page.

![Alt Image Text](./images/nifi-login.png "Nifi Login")

Enter `nifi` into the **User** field and `1234567890ACD` into the **Password** field and click **LOG IN**.

This should bring up the NiFi User Interface, which at this point is a blank canvas for orchestrating a data flow.

![Alt Image Text](./images/nifi-empty-canvas.png "Nifi Login")

Now you can add **Processor**s to create the pipeline. 

Let's start with the input. 

### Adding a `GetFile` Processor

We can now begin creating our data flow by adding a Processor to our canvas. To do this, drag the Processor icon from the top-left of the screen into the middle of the canvas and drop it there. 

![Alt Image Text](./images/nifi-drag-processor-into-canvas.png "Schema Registry UI")

This will give us a dialog that allows us to choose which Processor we want to add. We can see that there are a total of 290 processors currently available. We can browse through the list or use **filter types** box to filter-down to one or more processors.

![Alt Image Text](./images/nifi-add-processor.png "Schema Registry UI")

Enter **GetF** into the search field and the list will be reduced to two processors, the **GetFTP** and the **GetFile** processor. As the name implies, the first one can be used to get files from a FTP server, whereas the second one can be used to read local files. We will use the later here. Navigate to the **GetFile** and click **ADD**.

![Alt Image Text](./images/nifi-add-processor-search.png "Schema Registry UI")

You should now see the canvas with the **GetFile** processor. A yellow marker is shown on the processor, telling that the processor is not yet configured properly. 

![Alt Image Text](./images/nifi-canvas-with-getfile-processor-1.png "Schema Registry UI")

Double-click on the **GetFile** processor and the **Settings** page of the processor appears. Here you can change the name of the processor among other general properties.

![Alt Image Text](./images/nifi-getfile-processor-settings-1.png "Schema Registry UI")

Click on **Properties** tab to switch to the properties page.

![Alt Image Text](./images/nifi-getfile-processor-properties-1.png "Schema Registry UI")

On the properties page, we configure the properties for reading the data from the local file system.  

Set the properties as follows:

  * **Input Directory**: `/data-transfer/landing-zone`
  * **File Filter**: `[^\.].*\.csv`
  * **Recursive Subdirectories**: `false`
  * **Minimum File Age**: `5 sec`

The **Configure Processor** should look as shown below

![Alt Image Text](./images/nifi-getfile-processor-properties-2.png "Schema Registry UI")

Click **Apply** to close the window.

The `GetFile` processor still shows the yellow marker, this is because the out-going relationship is neither used nor terminated. Of course we want to use it, but for that we first need another Processor to store the data in S3 object storage. 

### Adding a `PutS3Object` Processor

Drag a new Processor onto the Canvas, just below the **GetFile** processor. 

Enter **PutS3** into the **Filter types** field on top left. Only a single processor, the `PutS3Object` is shown.

![Alt Image Text](./images/nifi-add-processor-search-puts3.png "Schema Registry UI")

Click on **Add** to add it to the canvas as well. The canvas should now look like shown below. You can drag around the processor to organize them in the right order. It is recommended to organize the in main flow direction, either top-to-bottom or left-to-right. 

![Alt Image Text](./images/nifi-canvas-with-two-processor.png "Schema Registry UI")

Let's configure the new processor. Double-click on the `PutS3Object` and navigate to **Properties**. Enter the following values:

  * **Bucket**: `flight-nifi-bucket`
  * **Object Key**: `/raw/airport/${ingestionTime}/${filename}`
  * **Region**: `US East (N. Virginia)`
  * **Endpoint Override URL**: `http://minio-1:9000`
  * **Use Path Style Access**: `true`
  * **AWS Credentials Provider Service**: click on the 3 dots and select **Create new service** and click **Add** to add a new service of type **AWSCredentialsProviderControllerService**. Click again on the 3 dots and select **Go To Service** and confirm with **Yes**. On the **Controller Services** pop-up page, click on the 3 dots right to the ` AWSCredentialsProviderControllerService` and select **Edit**. Navigate to the **Properties** tab and enter these values and click **Apply** and **Back to Processor**
  	* **Access Key ID**: `admin`
	* **Secret Access Key**: `bKhWxVF3kQoLY9kFmt91l+tDrEoZjqnWXzY9Eza`

The **Configure Processor** should look as shown below. 

![Alt Image Text](./images/nifi-puts3object-processor-properties-1.png "Schema Registry UI")

**Note**: NiFi does not display username and password values, they are instead shown as `Sensitive value set` when they hold a value.

Because we already saved the settings, we can click **Cancel** to close the pop-up window. 

We also use a variable `ingestionTime` in the **Object Key** expression above, which we need to set to the current timestamp when a file is processed. We will do that now by adding an additional **UpdateAttribute** processor.

### Set Variable using `UpdateAttribute` processor

Drag a new Processor onto the Canvas, in between the **GetFile** and **PutS3Object** processor. 

Enter **updateA** into the Filter field on top right. Only a single processor, the `UpdateAttribute ` is shown. Click **Add** to add it to the canvas as well.

Now let's configure the new processor. Double-click on the `UpdateAttribute ` and navigate to **Properties**. In this case we do not have to update an existing property but instead add a new one. Click on **+** in the upper right corner of the **Edit Processor** window. 

Enter `ingestionTime` into the **Property Name** and click **Ok**. Enter the following expression `${now():format("yyyy-MM-dd'T'HH:mm:ss")}` into the pop-up window for the value. 

![Alt Image Text](./images/nifi-updateattribute-processor-properties-1.png "Schema Registry UI")

Click **Ok** and then **Apply**.

Now we have 3 processors on the canvas, and we should organize them in the direction of the data flow, either horizontal (left to right) or vertical (top to bottom)

![Alt Image Text](./images/nifi-canvas-with-three-processor.png "Schema Registry UI")

Before we can run the pipeline, we of course have to connect the processors. 

### Connecting the Processors

Drag a connection from the **GetFile** processor to the **UpdateProcessor** and drop it. 

![Alt Image Text](./images/nifi-drag-connection.png "Schema Registry UI")

Make sure that the `success` **Relationship** is enabled and click **Add**. 

Repeat it for the connection from **UpdateAttribute** to **PutS3Object**. The data flow on the canvas should now look as shown below

![Alt Image Text](./images/nifi-canvas-with-connected-processor.png "Schema Registry UI")

The first two processor no longer hold the yellow marker, but instead show the red stop marker, meaning that these two processors can be started. But what about the last one, the **PutS3Object** processor?

If you navigate to the marker, a tool-tip will show the errors. 

![Alt Image Text](./images/nifi-puts3object-error-marker.png "Schema Registry UI")

We can see that there are 3 errors on the **PutS3Object** processor. The first one indicates, that the controller service we have created before is still disabled. We can easily enable it by right-clicking on the canvas and selecting **Enable All Controller Services** from the context menu. 

![](./images/nifi-enable-all-controller-services.png)

The other two errors are caused by the processor having two outgoing relationships, which are not "used". We have to terminate them, if we have no use for it. 

Double-click on the **PutS3Object** processor and navigate to **Relationships** and set the check-boxes for both relationships to **terminate**. 

![Alt Image Text](./images/nifi-terminate-relationships.png "Schema Registry UI")

Click **Apply** to save the settings.

Now our data flow is ready, so let's run it. 

### Starting the Data Flow 

Select all 3 processor (click ctrl-A) and navigate to the start arrow and click on it

![Alt Image Text](./images/nifi-start-dataflow.png "Schema Registry UI")

This will run the 3 processors. All three processors now show the green "started" or "running" marker. 

![Alt Image Text](./images/nifi-running-dataflow.png "Schema Registry UI")

### Copy a file into the landing zone

Now let's copy a file to be uploaded into the `/data-transfer/landing-zone` folder. You can either use a terminal window to do that or the file browser UI, as shown here. 

Navigate to <http://dataplatform:28178> and login with `admin` for the **Username** and also `admin` for the **Password**. 

![Alt Image Text](./images/file-browser-home.png "Schema Registry UI")

Navigate to **airport-data** folder by double-clicking on it and select the **airports.csv** file. 

![Alt Image Text](./images/file-browser-airport-folder.png "Schema Registry UI")

In the menu bar, click on the **Copy file** icon 

![Alt Image Text](./images/file-browser-copy-file-1.png "Schema Registry UI")

and navigate to the **landing-zone** folder and click **COPY**

![Alt Image Text](./images/file-browser-copy-file-2.png "Schema Registry UI")

Let's see if our NiFi data flow has done its work!

In a terminal, use the `mc tree` command to  view the `flight-nifi-bucket`

```bash
docker exec -ti minio-mc mc tree --files minio-1/flight-nifi-bucket/
```

if should show an output similar to the one below

```bash
ubuntu@ip-172-26-9-12:~/bigdata-spark-workshop/01-environment/docker/data-transfer$ docker exec -ti minio-mc mc tree --files minio-1/flight-nifi-bucket/
minio-1/flight-nifi-bucket/
└─ raw
   └─ airport
      └─ 2025-05-29T21:03:52
         └─ airports.csv
```

We can see that the file has been loaded into a folder with the timestamp of the file ingestion.

### Additional steps

 * stop one of the processors and check the flow file in the buffer
 * check that the new file is uploaded under a different folder (ingestion timestamp) 