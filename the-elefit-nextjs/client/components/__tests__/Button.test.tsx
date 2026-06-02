import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { Button } from '../ui/button';

describe('Button Component', () => {
  it('should render children correctly', () => {
    const { getByText } = render(<Button>Click me</Button>);
    expect(getByText('Click me')).toBeInTheDocument();
  });

  it('should apply default button styling', () => {
    const { container } = render(<Button>Test</Button>);
    const button = container.querySelector('button');
    expect(button).toHaveClass('inline-flex items-center justify-center');
  });
});
