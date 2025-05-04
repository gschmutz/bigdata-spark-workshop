# AKHQ

Kafka GUI for Apache Kafka to manage topics, topics data, consumers group, schema registry, connect and more... 

**[Website](https://akhq.io/)** | **[Documentation](https://akhq.io/docs/)** | **[GitHub](https://github.com/tchiotludo/akhq)**

## How to enable?

```
platys init --enable-services AKHQ
platys gen
```

## How to use it?

Navigate to <http://:28107>.
If authentication is enabled, login with user `admin` and password `abc123!`.

To use the REST API <http://:28107/api> (see <https://akhq.io/docs/api.html>)


### Monitoring API
  
  * <http://:28320/info>  
  * <http://:28320/health>
  * <http://:28320/loggers>
  * <http://:28320/metrics>
  * <http://:28320/prometheus>