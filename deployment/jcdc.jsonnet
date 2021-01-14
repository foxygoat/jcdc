{
  config:: {
    hostname: null,
    docker_tag: 'latest',
  },
  configure(overlay={}, hostname=null, docker_tag=null)::
    self + overlay + {
      config+: std.prune({
        hostname: hostname,
        docker_tag: docker_tag,
      }),
    },

  manifest: [
    $.namespace,
    $.service,
    $.serviceAccount,
    $.clusterRole,
    $.clusterRoleBinding,
    $.deployment,
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
  serviceAccount:: {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: 'jcdc',
      namespace: 'jcdc',
    },
  },
  clusterRole:: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRole',
    metadata: {
      name: 'jcdc',
    },
    rules: [{
      apiGroups: ['*'],
      resources: ['*'],
      verbs: ['*'],
    }],
  },
  clusterRoleBinding:: {
    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'ClusterRoleBinding',
    metadata: {
      name: 'jcdc',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'jcdc',
    },
    subjects: [{
      kind: 'ServiceAccount',
      name: 'jcdc',
      namespace: 'jcdc',
    }],
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
          serviceAccountName: 'jcdc',
          automountServiceAccountToken: true,
          containers: [
            {
              local policy(tag) = if tag == 'latest' || std.startsWith(tag, 'pr') then 'Always' else 'IfNotPresent',
              image: 'foxygoat/jcdc:%s' % $.config.docker_tag,
              imagePullPolicy: policy($.config.docker_tag),
              name: 'jcdc',
              ports: [{ containerPort: 8080, name: 'http', protocol: 'TCP' }],
              env: [{
                name: 'JCDC_API_KEY',
                valueFrom: { secretKeyRef: { key: 'apikey', name: 'jcdc' } },
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
}
