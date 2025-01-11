import BrowserP2PT from './p2pt.js'
import wrtc from '@koush/wrtc'

class P2PT extends BrowserP2PT {
  _wrtc: wrtc
  /**
   *
   * @param array announceURLs List of announce tracker URLs
   * @param string identifierString Identifier used to discover peers in the network
   */
  constructor (announceURLs = [], identifierString = '', peerId?: Uint8Array) {

    super(announceURLs, identifierString, peerId)

    this._wrtc = wrtc
  }
}

export { P2PT as default }
