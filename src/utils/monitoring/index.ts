interface Performance {
  pageLoad: number;
  firstContentfulPaint: number;
  domInteractive: number;
}

class PerformanceMonitor {
  private metrics: Performance = {
    pageLoad: 0,
    firstContentfulPaint: 0,
    domInteractive: 0
  };

  start() {
    if (typeof window !== 'undefined') {
      window.addEventListener('load', () => this.measurePageLoad());
      this.observePaintTiming();
    }
  }

  private measurePageLoad() {
    if (window.performance) {
      const timing = window.performance.timing;
      this.metrics.pageLoad = timing.loadEventEnd - timing.navigationStart;
      this.metrics.domInteractive = timing.domInteractive - timing.navigationStart;
    }
  }

  private observePaintTiming() {
    if (window.PerformanceObserver) {
      const observer = new PerformanceObserver((list) => {
        const entries = list.getEntries();
        entries.forEach(entry => {
          if (entry.name === 'first-contentful-paint') {
            this.metrics.firstContentfulPaint = entry.startTime;
          }
        });
      });

      observer.observe({ entryTypes: ['paint'] });
    }
  }

  getMetrics(): Performance {
    return { ...this.metrics };
  }
}

export const performanceMonitor = new PerformanceMonitor();