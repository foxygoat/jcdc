{
  config:: {
    hostname: null,
    docker_tag: 'latest',
    dev: '',
    commit_sha: '',

    // derived
    nameSuffix: if self.dev != '' then '-' + self.dev else '',
    hostPrefix: if self.dev != '' then self.dev + '.' else '',
  },
  configure(overlay={}, hostname=null, docker_tag=null, dev=null, commit_sha=null)::
    self + overlay + {
      config+: std.prune({
        hostname: hostname,
        docker_tag: docker_tag,
        dev: dev,
        commit_sha: commit_sha,
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
      namespace: 'jcdc',
      name: 'jcdc' + $.config.nameSuffix,
      labels: {
        app: 'jcdc',
        dev: $.config.dev,
      },
    },
    spec: {
      ports: [{ name: 'http', port: 8080 }],
      selector: {
        app: 'jcdc',
        dev: $.config.dev,
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
      namespace: 'jcdc',
      name: 'jcdc' + $.config.nameSuffix,
      labels: {
        app: 'jcdc',
        dev: $.config.dev,
      },
    },
    spec: {
      selector: {
        matchLabels: {
          app: 'jcdc',
          dev: $.config.dev,
        },
      },
      template: {
        metadata: {
          labels: {
            app: 'jcdc',
            dev: $.config.dev,
          },
          annotations: {
            commit_sha: $.config.commit_sha,
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
      namespace: 'jcdc',
      name: 'jcdc' + $.config.nameSuffix,
      labels: {
        app: 'jcdc',
        dev: $.config.dev,
      },
      annotations: {
        'cert-manager.io/cluster-issuer': 'letsencrypt',
        'traefik.ingress.kubernetes.io/router.entrypoints': 'https',
      },
    },
    spec: {
      rules: [
        {
          host: $.config.hostPrefix + $.config.hostname,
          http: {
            paths: [
              {
                backend: {
                  service: {
                    name: 'jcdc' + $.config.nameSuffix,
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
          hosts: [$.config.hostPrefix + $.config.hostname],
          secretName: 'jcdc' + $.config.nameSuffix + '-https-cert',
        },
      ],
    },
  },
}
