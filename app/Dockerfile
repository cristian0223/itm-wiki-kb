# Imagen de la wiki / base de conocimiento del equipo.
# Parte de la imagen oficial de LinuxServer.io para BookStack y le agrega:
#  - un script de arranque que conecta cache y sesiones con Redis
#  - un archivo build-info.json con el commit desplegado (trazabilidad CI/CD)
ARG BOOKSTACK_TAG=latest
FROM lscr.io/linuxserver/bookstack:${BOOKSTACK_TAG}

ARG GIT_SHA=local
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="itm-wiki-bookstack" \
      org.opencontainers.image.description="Wiki / Knowledge base - Actividad 5 Despliegue de software ITM" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}"

COPY root/ /

RUN chmod 755 /custom-cont-init.d/* \
    && mkdir -p /app/www/public \
    && printf '{"app":"bookstack","commit":"%s","built":"%s"}\n' "${GIT_SHA}" "${BUILD_DATE}" \
       | tee /itm-build-info.json > /app/www/public/build-info.json

EXPOSE 80
