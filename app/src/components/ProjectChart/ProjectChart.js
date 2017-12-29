import React from 'react'
import PropTypes from 'prop-types'
import {
  compose,
  pure,
  withState,
  withHandlers,
  lifecycle
} from 'recompose'
import { Merge } from 'animate-components'
import { fadeIn, slideUp } from 'animate-keyframes'
import { Bar, Chart } from 'react-chartjs-2'
import moment from 'moment'
import { formatNumber, formatBTC } from '../../utils/formatting'
import './ProjectChart.css'

export const calculateBTCVolume = ({volume, priceUsd, priceBtc}) => {
  return parseFloat(volume) / parseFloat(priceUsd) * parseFloat(priceBtc)
}

export const calculateBTCMarketcap = ({marketcap, priceUsd, priceBtc}) => {
  return parseFloat(marketcap) / parseFloat(priceUsd) * parseFloat(priceBtc)
}

const TimeFilterItem = ({disabled, interval, setFilter, value = '1d'}) => {
  let cls = interval === value ? 'activated' : ''
  if (disabled) {
    cls += ' disabled'
  }
  return (
    <div
      className={cls}
      onClick={() => !disabled && setFilter(value)}>{value}</div>
  )
}

const TimeFilter = props => (
  <div className='time-filter'>
    <TimeFilterItem value={'1d'} {...props} />
    <TimeFilterItem value={'1w'} {...props} />
    <TimeFilterItem value={'2w'} {...props} />
    <TimeFilterItem value={'1m'} {...props} />
  </div>
)

const CurrencyFilter = ({isToggledBTC, showBTC, showUSD}) => (
  <div className='currency-filter'>
    <div
      className={isToggledBTC ? 'activated' : ''}
      onClick={showBTC}>BTC</div>
    <div
      className={!isToggledBTC ? 'activated' : ''}
      onClick={showUSD}>USD</div>
  </div>
)

const MarketcapToggle = ({isToggledMarketCap, toggleMarketcap}) => (
  <div className='marketcap-toggle'>
    <div
      className={isToggledMarketCap ? 'activated' : ''}
      onClick={() => toggleMarketcap(!isToggledMarketCap)}>MarketCap</div>
  </div>
)

const getChartDataFromHistory = (history = [], isToggledBTC, isToggledMarketCap) => {
  const priceDataset = {
    label: 'price',
    type: 'LineWithLine',
    fill: !isToggledMarketCap,
    strokeColor: '#7a9d83eb',
    borderColor: '#7a9d83eb',
    borderWidth: 1,
    backgroundColor: 'rgba(239, 242, 236, 0.5)',
    pointBorderWidth: 2,
    yAxisID: 'y-axis-1',
    data: history ? history.map(data => {
      if (isToggledBTC) {
        const price = parseFloat(data.priceBtc)
        return formatBTC(price)
      }
      return data.priceUsd
    }) : []}
  const volumeDataset = {
    label: 'volume',
    fill: false,
    type: 'bar',
    yAxisID: 'y-axis-2',
    borderColor: 'rgba(49, 107, 174, 0.5)',
    borderWidth: 1,
    pointBorderWidth: 2,
    data: history ? history.map(data => {
      if (isToggledBTC) {
        return calculateBTCVolume(data)
      }
      return parseFloat(data.volume)
    }) : []}
  const marketcapDataset = !isToggledMarketCap ? null : {
    label: 'marketcap',
    type: 'line',
    fill: false,
    yAxisID: 'y-axis-3',
    borderColor: 'rgb(200, 47, 63)',
    borderWidth: 1,
    pointBorderWidth: 2,
    data: history ? history.map(data => {
      if (isToggledBTC) {
        return calculateBTCMarketcap(data)
      }
      return parseFloat(data.volume)
    }) : []}
  return {
    labels: history ? history.map(data => moment(data.datetime).utc()) : [],
    datasets: [priceDataset, volumeDataset, marketcapDataset].reduce((acc, curr) => {
      if (curr) acc.push(curr)
      return acc
    }, [])
  }
}

export const ProjectChart = ({
  history,
  isError,
  isEmpty,
  isLoading,
  errorMessage,
  setSelected,
  selected,
  ...props
}) => {
  if (isLoading) {
    return (
      <div className='project-chart-loader'>
        <h2>Loading...</h2>
      </div>
    )
  }
  if (isError) {
    return (
      <div>
        <h2>We can't get the data from our server now... ;(</h2>
        <p>{errorMessage}</p>
      </div>
    )
  }
  const chartData = getChartDataFromHistory(history, props.isToggledBTC, props.isToggledMarketCap)
  const max = Math.max(...chartData.datasets[1].data)
  const chartOptions = {
    responsive: true,
    showTooltips: false,
    pointDot: false,
    scaleShowLabels: false,
    datasetFill: false,
    scaleFontSize: 0,
    animation: false,
    pointRadius: 0,
    tooltips: {
      callbacks: {
        title: item => '',
        label: (tooltipItem, data) => {
          return props.isToggledBTC
            ? formatBTC(tooltipItem.yLabel)
            : formatNumber(tooltipItem.yLabel, 'USD')
        }
      }
    },
    legend: {
      display: false
    },
    elements: {
      point: {
        hitRadius: 2,
        hoverRadius: 2,
        radius: 0
      }
    },
    scales: {
      yAxes: [{
        id: 'y-axis-1',
        type: 'linear',
        display: true,
        position: 'left',
        ticks: {
          display: true,
          beginAtZero: true
        },
        gridLines: {
          drawBorder: true,
          display: true
        }
      }, {
        id: 'y-axis-2',
        type: 'linear',
        display: false,
        position: 'right',
        ticks: {
          max: max * 2.2
        },
        labels: {
          show: true
        }
      }, {
        id: 'y-axis-3',
        type: 'linear',
        ticks: {
          mirror: true,
          padding: 50,
          display: false
        },
        gridLines: {
          display: false
        },
        display: props.isToggledMarketCap,
        position: 'right'
      }],
      xAxes: [{
        type: 'time',
        ticks: {
          autoSkipPadding: 1,
          callback: function (value, index, values) {
            if (!values[index]) { return }
            const time = moment.utc(values[index]['value'])
            if (props.interval === '1d') {
              return time.format('HH:mm')
            }
            return time.format('D MMM')
          }},
        gridLines: {
          drawBorder: true,
          display: true
        }
      }]
    }
  }

  return (
    <div className='project-dp-chart'>
      <div className='chart-header'>
        <TimeFilter {...props} />
        <div className='selected-value'>{selected !== null &&
          <Merge
            one={{ name: fadeIn, duration: '0.3s', timingFunction: 'ease-in' }}
            two={{ name: slideUp, duration: '0.5s', timingFunction: 'ease-out' }}
            as='div'
          >
            <span className='selected-value-datetime'>
              {moment(chartData.labels[selected]).utc().format('MMMM DD, YYYY')}
            </span>
          </Merge>}</div>
        <div className='selected-value'>{selected !== null &&
          <Merge
            one={{ name: fadeIn, duration: '0.3s', timingFunction: 'ease-in' }}
            two={{ name: slideUp, duration: '0.5s', timingFunction: 'ease-out' }}
            as='div'
          >
            <span className='selected-value-data'>Price: {props.isToggledBTC
              ? formatBTC(parseFloat(chartData.datasets[0].data[selected]))
              : formatNumber(chartData.datasets[0].data[selected], 'USD')}</span>
            <span className='selected-value-data'>Volume: {props.isToggledBTC
              ? formatBTC(parseFloat(chartData.datasets[1].data[selected]))
              : formatNumber(chartData.datasets[1].data[selected], 'USD')}</span>
          </Merge>}</div>
      </div>
      <Bar
        className='graph'
        data={chartData}
        options={chartOptions}
        redraw
        height={100}
        onElementsClick={elems => {
          elems[0] && setSelected(elems[0]._index)
        }}
        style={{ transition: 'opacity 0.25s ease' }}
      />
      <div className='chart-footer'>
        <CurrencyFilter {...props} />
        <MarketcapToggle {...props} />
      </div>
    </div>
  )
}

const enhance = compose(
  withState('isToggledBTC', 'currencyToggle', false),
  withHandlers({
    showBTC: ({ currencyToggle }) => e => currencyToggle(true),
    showUSD: ({ currencyToggle }) => e => currencyToggle(false)
  }),
  withState('isToggledMarketCap', 'toggleMarketcap', false),
  lifecycle({
    componentWillMount () {
      Chart.defaults.LineWithLine = Chart.defaults.line
      Chart.controllers.LineWithLine = Chart.controllers.line.extend({
        draw: function (ease) {
          Chart.controllers.line.prototype.draw.call(this, ease)

          if (this.chart.tooltip._active && this.chart.tooltip._active.length) {
            const activePoint = this.chart.tooltip._active[0]
            const ctx = this.chart.ctx
            const x = activePoint.tooltipPosition().x
            const topY = this.chart.scales['y-axis-1'].top
            const bottomY = this.chart.scales['y-axis-1'].bottom

            ctx.save()
            ctx.beginPath()
            ctx.moveTo(x, topY)
            ctx.lineTo(x, bottomY)
            ctx.lineWidth = 2
            ctx.strokeStyle = 'rgba(49, 107, 174, 0.5)'
            ctx.stroke()
            ctx.restore()
          }
        }
      })
    }
  }),
  pure
)

ProjectChart.propTypes = {
  isLoading: PropTypes.bool.isRequired,
  isError: PropTypes.bool.isRequired,
  history: PropTypes.array.isRequired,
  isEmpty: PropTypes.bool
}

ProjectChart.defaultProps = {
  isLoading: true,
  isEmpty: true,
  isError: false,
  history: []
}

export default enhance(ProjectChart)