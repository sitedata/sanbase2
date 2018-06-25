import 'rxjs'
import { combineEpics } from 'redux-observable'
import handleFollowProject from './handleFollowProject'
import handleOffline from './handleOffline'
import handleLauched from './handleLaunch'
import handleEmailLogin, { handleLoginSuccess } from './handleEmailLogin'
import handleEthLogin from './handleEthLogin'

export default combineEpics(
  handleFollowProject,
  handleOffline,
  handleLauched,
  handleEmailLogin,
  handleLoginSuccess,
  handleEthLogin
)