import React from 'react';

interface Props {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}

export default function Pagination({ currentPage, totalPages, onPageChange }: Props) {
  return (
    <div className="flex items-center justify-between">
      <div className="text-sm text-gray-700">
        第 {currentPage} 页，共 {totalPages} 页
      </div>
      <div className="flex space-x-2">
        <button
          onClick={() => onPageChange(currentPage - 1)}
          disabled={currentPage === 1}
          className="px-3 py-1 border rounded-md text-sm disabled:opacity-50"
        >
          上一页 Prev
        </button>
        <button
          onClick={() => onPageChange(currentPage + 1)}
          disabled={currentPage === totalPages}
          className="px-3 py-1 border rounded-md text-sm disabled:opacity-50"
        >
          下一页 Next
        </button>
      </div>
    </div>
  );
}