import React, { Component } from 'react'
import Slider from 'react-slick'
import Widget from '../Widget/Widget'
import InsightsWidgetItem from './InsightsWidgetItem'
import './InsightsWidget.css'
import './SliderWidget.css'
import { graphql } from 'react-apollo'
import { insightsWidgetGQL } from './insightsWidgetGQL'

const sliderSettings = {
  dots: true,
  infinite: true,
  speed: 500,
  slidesToShow: 1,
  slidesToScroll: 1,
  autoplaySpeed: 5000,
  autoplay: true,
  arrows: false
}

const parseInsightsWidgetGQLProps = ({ data: { allInsights = [] } }) => ({
  insights: allInsights.slice(0, 5)
})

export class InsightsWidget extends Component {
  render () {
    const { insights = [] } = this.props

    return (
      <Widget className='InsightsWidget'>
        <Slider {...sliderSettings}>
          {insights.map(({ id, createdAt, title, user, text }) => (
            <InsightsWidgetItem
              key={id}
              id={id}
              title={title}
              user={user}
              text={text}
              createdAt={createdAt}
            />
          ))}

          {/* <InsightsWidgetItem
            title='Recent notasd asdfas dfaf genesis activity'
            author='konduchi'
            time='Sep 20, 2018'
          /> */}
        </Slider>
      </Widget>
    )
  }
}

export default graphql(insightsWidgetGQL, {
  props: parseInsightsWidgetGQLProps
})(InsightsWidget)
