{
  manifest+: [$.sealedSecret],
  config+: {
    hostname: 'jcdc.jul.run',
  },
  sealedSecret:: import 'secret.json',
}
