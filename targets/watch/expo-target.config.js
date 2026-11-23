/** Apple Watch remote: talks to the iPhone app over WatchConnectivity (see modules/compas-watch). */
/** @type {import('@bacons/apple-targets/app.plugin').ConfigFunction} */
module.exports = () => ({
  type: 'watch',
  name: 'CompasRemoteWatch',
  displayName: 'compás',
  // Appended to the iPhone app's bundle ID, so it follows any future ID change.
  bundleIdentifier: '.watchkitapp',
  icon: '../../assets/icon.png',
  deploymentTarget: '10.0',
  frameworks: ['WatchConnectivity'],
});
