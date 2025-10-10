import React from 'react';
import { Line } from 'react-chartjs-2';
import { useCheckInTrends } from '../../../hooks/useCheckInTrends';
import LoadingSpinner from '../../common/LoadingSpinner';
import ErrorMessage from '../../common/ErrorMessage';

const CheckInTrends: React.FC = () => {
  const { trends, loading, error } = useCheckInTrends();

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMessage message={error.message} />;

  const data = {
    labels: trends.map(trend => trend.date),
    datasets: [
      {
        label: '总签到',
        data: trends.map(trend => trend.total),
        borderColor: 'rgb(75, 192, 192)',
        tension: 0.1,
      },
      {
        label: '常规签到',
        data: trends.map(trend => trend.regular),
        borderColor: 'rgb(54, 162, 235)',
        tension: 0.1,
      },
      {
        label: '额外签到',
        data: trends.map(trend => trend.extra),
        borderColor: 'rgb(255, 99, 132)',
        tension: 0.1,
      },
    ],
  };

  const options = {
    responsive: true,
    plugins: {
      legend: {
        position: 'top' as const,
      },
      title: {
        display: true,
        text: '签到趋势 Check-in Trends',
      },
    },
    scales: {
      y: {
        beginAtZero: true,
        ticks: {
          stepSize: 1,
        },
      },
    },
  };

  return (
    <div className="bg-white p-6 rounded-lg shadow">
      <Line data={data} options={options} />
    </div>
  );
};

export default CheckInTrends;