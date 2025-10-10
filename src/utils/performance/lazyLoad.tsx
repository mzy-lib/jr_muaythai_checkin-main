import React from 'react';
import LoadingSpinner from '../../components/common/LoadingSpinner';

export const lazyLoadComponent = (importFunc: () => Promise<{ default: React.ComponentType<any> }>) => {
  const LazyComponent = React.lazy(importFunc);

  return (props: any) => (
    <React.Suspense fallback={<LoadingSpinner />}>
      <LazyComponent {...props} />
    </React.Suspense>
  );
};