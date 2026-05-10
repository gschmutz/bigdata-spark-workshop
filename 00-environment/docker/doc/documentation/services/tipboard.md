# Tipboard

Tipboard - in-house, tasty, local dashboarding system 

**[Website](https://github.com/allegro/tipboard)** | **[Documentation](https://tipboard.readthedocs.io/en/latest/)** | **[GitHub](https://github.com/allegro/tipboard)**

## How to enable?

```bash
platys init --enable-services TIPBOARD
platys gen
```

## How to use it?

Navigate to <http://${PUBLIC_IP}:28172>

## Checking for errors

In case of an error on startup, Tipboard does not show the error details in `docker logs -f tipboard`. You can find more details about the error with

```bash
docker exec -ti tipboard bash 

cat /root/logs/tipboard-stderr---supervisor*.log
```

## Sending data to a tile

the following curl statement sends data to a tile of type `just_value` with the tile-id of `status`

```bash
curl http://dataplatform:28172/api/v0.1/e2c3275d0e1a4bc0da360dd225d74a43/push -X POST -d "tile=just_value" -d "key=status" -d 'data={"title": "Next release:", "description": "(days remaining)", "just-value": "23"}'
```

