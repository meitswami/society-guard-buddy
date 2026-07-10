import type { ReactNode } from 'react';
import { DescriptiveStatCard } from '@/components/DescriptiveStatCard';
import { FINANCE_PERIOD_METRICS } from '@/lib/descriptiveMetricCopy';

export function PeriodMetric({
  metricKey,
  value,
  valueClassName,
  className,
}: {
  metricKey: keyof typeof FINANCE_PERIOD_METRICS;
  value: ReactNode;
  valueClassName?: string;
  className?: string;
}) {
  const copy = FINANCE_PERIOD_METRICS[metricKey];
  return (
    <DescriptiveStatCard
      variant="stat"
      title={copy.title}
      caption={copy.title}
      description={copy.description}
      howCalculated={copy.howCalculated}
      value={value}
      valueClassName={valueClassName}
      className={className}
    />
  );
}
