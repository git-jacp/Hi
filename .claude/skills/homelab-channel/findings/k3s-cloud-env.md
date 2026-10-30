# k3s en el entorno cloud de Claude Code — hallazgos (2026-10-30)

## Resumen
k3s **se instala** pero **no arranca** en este entorno cloud: el kubelet
rechaza explícitamente el host porque usa **cgroup v1** (jerarquía híbrida
legacy), y k3s v1.36+ ya no soporta cgroup v1.

Esto es independiente de red/whitelist: una vez abiertos `get.k3s.io` y
`update.k3s.io`, la instalación en sí funciona sin problema.

## Timings medidos

| Paso | Tiempo |
|---|---|
| `curl -sfL https://get.k3s.io \| sh -` (descarga binario + symlinks + unit systemd) | ~5.2s |
| Arranque de `k3s server` hasta "Kube API server is now running" | ~3s |
| Arranque hasta el crash del kubelet por cgroup v1 | ~3-4s tras lo anterior |

## Causa raíz

```
Error: failed to validate kubelet configuration, error: kubelet is
configured to not run on a host using cgroup v1. cgroup v1 support is
unsupported and will be removed in a future release
```

Verificado con:
```
$ stat -fc %T /sys/fs/cgroup
tmpfs                      # no es cgroup2fs unificado
$ mount | grep cgroup
cgroup on /sys/fs/cgroup/cpu ...        # controladores v1 montados por separado
cgroup2 on /sys/fs/cgroup/unified ...   # solo un mount "unified" adicional, no es el modo v2 puro
```

## Otros bloqueos (independientes del anterior)

- **No hay systemd como PID 1** (`PID 1 = process_api`), así que la unit
  `k3s.service` que instala el script oficial no se puede habilitar/arrancar
  con `systemctl`. Solo sirve ejecutar `k3s server` a mano (en foreground o
  detached con `setsid`/`nohup`), nunca como servicio systemd.
- El **daemon de Docker no arranca** en este entorno (binario presente,
  sin `dockerd` corriendo, falta `/var/run/docker.sock`). No es el camino
  recomendado aquí; usar `k3s` con su containerd embebido en su lugar.

## Conclusión

Tal como está configurado hoy, este entorno cloud **no puede ser un gemelo
funcional de un homelab con k3s**: aunque la red y los binarios ya están
accesibles, el kernel/cgroups del host (cgroup v1, sin systemd) bloquean
el arranque real del kubelet. Haría falta que el operador del entorno
cambie la imagen base/kernel a cgroup v2 unificado para que esto sea
viable; no es algo arreglable desde dentro de la sesión.
