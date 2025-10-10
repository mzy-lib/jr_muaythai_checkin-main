import React from 'react';

interface ImportError {
  rowNumber: number;
  errors: string[];
}

interface Props {
  errors: ImportError[];
  onClose: () => void;
}

export default function ImportErrors({ errors, onClose }: Props) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg p-6 max-w-2xl w-full max-h-[80vh] overflow-y-auto">
        <h2 className="text-xl font-bold mb-4 text-red-600">
          导入错误 Import Errors
        </h2>
        
        <div className="space-y-4">
          {errors.map((error, index) => (
            <div key={index} className="border-b pb-2">
              <p className="font-medium">Row {error.rowNumber}:</p>
              <ul className="list-disc pl-5 text-sm text-red-600">
                {error.errors.map((err, i) => (
                  <li key={i}>{err}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-6 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300"
          >
            关闭 Close
          </button>
        </div>
      </div>
    </div>
  );
}