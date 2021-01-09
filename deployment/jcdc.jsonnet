{
  config:: {
    hostname: null,
    docker_tag: 'latest',
  },
  configure(hostname=null, docker_tag=null)::
    self {
      config+: std.prune({
        hostname: hostname,
        docker_tag: docker_tag,
      }),
    },

  manifest: [
    $.namespace,
    $.service,
    $.deployment,
    $.secret,
    if $.config.hostname != null then $.ingress,
  ],
  namespace:: {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: 'jcdc',
    },
  },
  service:: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: 'jcdc',
      namespace: 'jcdc',
    },
    spec: {
      ports: [{ name: 'http', port: 8080 }],
      selector: {
        app: 'jcdc',
      },
    },
  },
  deployment:: {
    apiVersion: 'apps/v1',
    kind: 'Deployment',
    metadata: {
      labels: {
        app: 'jcdc',
      },
      name: 'jcdc',
      namespace: 'jcdc',
    },
    spec: {
      selector: {
        matchLabels: {
          app: 'jcdc',
        },
      },
      template: {
        metadata: {
          labels: {
            app: 'jcdc',
          },
        },
        spec: {
          containers: [
            {
              image: 'foxygoat/jcdc:%s' % $.config.docker_tag,
              name: 'jcdc',
              ports: [{ containerPort: 8080, name: 'http', protocol: 'TCP' }],
              env: [{
                name: 'JCDC_API_KEY',
                valueFrom: { secretKeyRef: { key: 'key', name: 'apikey' } },
              }],
            },
          ],
        },
      },
    },
  },
  ingress:: {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'Ingress',
    metadata: {
      annotations: {
        'cert-manager.io/cluster-issuer': 'letsencrypt',
        'traefik.ingress.kubernetes.io/router.entrypoints': 'https',
      },
      name: 'jcdc',
      namespace: 'jcdc',
    },
    spec: {
      rules: [
        {
          host: $.config.hostname,
          http: {
            paths: [
              {
                backend: {
                  service: {
                    name: 'jcdc',
                    port: {
                      name: 'http',
                    },
                  },
                },
                path: '/',
                pathType: 'Prefix',
              },
            ],
          },
        },
      ],
      tls: [
        {
          hosts: [$.config.hostname],
          secretName: 'jcdc-https-cert',
        },
      ],
    },
  },
  secret:: {
    apiVersion: 'v1',
    kind: 'Secret',
    metadata: {
      namespace: 'jcdc',
      name: 'apikey',
    },
    data: {
      key: std.base64('secret'),  // ⚠️ needs to be overridden on a per-site basis
    },
  },
}
