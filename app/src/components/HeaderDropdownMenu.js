import React from 'react'
import { Button, Popup, Divider, Icon } from 'semantic-ui-react'
import { NavLink, Link } from 'react-router-dom'
import FeedbackBtn from './FeedbackBtn'
import './HeaderDropdownMenu.css'
import SmoothDDItem from './SmoothDropdown/SmoothDDItem'

const HeaderDesktopDropMenu = ({ isLoggedin, logout }) => {
  if (isLoggedin) {
    return (
      <div className='user-auth-control'>
        <FeedbackBtn />
        {/* <Popup */}
        <SmoothDDItem
          mouseLeaveDelay={2000}
          basic
          wide
          trigger={<Button circular icon='user' />}
          id={0}
          on='hover'
        >
          <div className='app-menu-popup'>
            <Link className='app-menu__page-link' to={'/roadmap'}>
              <Icon name='map' />
              Roadmap
            </Link>
            <Link className='app-menu__page-link' to={'/account'}>
              <Icon name='setting' />
              Account Settings
            </Link>
            <Divider />
            <Button className='logoutBtn' color='orange' basic onClick={logout}>
              Logout
            </Button>
          </div>
        </SmoothDDItem>
        {/* </Popup> */}
      </div>
    )
  }
  return (
    <div className='user-auth-control'>
      <NavLink to={'/login'}>Login</NavLink>
    </div>
  )
}

export default HeaderDesktopDropMenu
