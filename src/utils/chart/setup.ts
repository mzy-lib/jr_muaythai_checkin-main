import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
  BarElement,
  Filler
} from 'chart.js';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

// Set global defaults
ChartJS.defaults.font.family = 'system-ui, -apple-system, sans-serif';
ChartJS.defaults.color = '#6B7280';
ChartJS.defaults.borderColor = '#E5E7EB';

// Export configured ChartJS
export { ChartJS };