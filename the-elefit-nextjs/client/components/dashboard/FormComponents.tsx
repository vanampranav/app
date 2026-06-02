import { useState } from 'react';

interface FormFieldProps {
  label: string;
  children: React.ReactNode;
  required?: boolean;
}

const FormField = ({ label, children, required = false }: FormFieldProps) => (
  <div className="flex flex-col gap-2">
    <label className="text-white font-inter text-sm">
      {label}
      {required && <span className="text-red-500 ml-1">*</span>}
    </label>
    {children}
  </div>
);

interface TextInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  type?: string;
  suffix?: string;
}

const TextInput = ({ value, onChange, placeholder, type = 'text', suffix }: TextInputProps) => {
  if (suffix) {
    return (
      <div className="relative">
        <input
          type={type}
          value={value}
          onChange={e => onChange(e.target.value)}
          className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-white placeholder-gray-500 focus:border-[#CCD853] focus:outline-none"
          placeholder={placeholder}
        />
        <span className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 text-sm">
          {suffix}
        </span>
      </div>
    );
  }

  return (
    <input
      type={type}
      value={value}
      onChange={e => onChange(e.target.value)}
      className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-white placeholder-gray-500 focus:border-[#CCD853] focus:outline-none"
      placeholder={placeholder}
    />
  );
};

interface SelectInputProps {
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
  placeholder?: string;
}

const SelectInput = ({ value, onChange, options, placeholder }: SelectInputProps) => (
  <div className="relative">
    <select
      value={value}
      onChange={e => onChange(e.target.value)}
      className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-white appearance-none focus:border-[#CCD853] focus:outline-none"
    >
      {placeholder && <option value="">{placeholder}</option>}
      {options.map(option => (
        <option key={option.value} value={option.value}>
          {option.label}
        </option>
      ))}
    </select>
    <div className="absolute right-3 top-1/2 transform -translate-y-1/2 pointer-events-none">
      <svg width="12" height="8" viewBox="0 0 12 8" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path
          d="M1 1.5L6 6.5L11 1.5"
          stroke="#999"
          strokeWidth="1.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </div>
  </div>
);

interface TextAreaProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  rows?: number;
}

const TextArea = ({ value, onChange, placeholder, rows = 3 }: TextAreaProps) => (
  <textarea
    value={value}
    onChange={e => onChange(e.target.value)}
    rows={rows}
    className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-white placeholder-gray-500 focus:border-[#CCD853] focus:outline-none resize-none"
    placeholder={placeholder}
  />
);

export { FormField, TextInput, SelectInput, TextArea };
