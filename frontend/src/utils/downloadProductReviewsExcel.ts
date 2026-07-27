import * as XLSX from 'xlsx'
import type { DbProductReview } from '../api/productReviews'

export type ProductReviewExcelRow = DbProductReview & {
  employeeName?: string
}

export function downloadProductReviewsExcel(rows: ProductReviewExcelRow[]) {
  const sheetRows = rows.map((row) => ({
    'Employee Code': row.employeeCode,
    'Employee Name': row.employeeName ?? '',
    Route: row.route,
    'Customer Code': row.customerCode,
    'Customer Name': row.customerName,
    'Item Code': row.itemCode,
    'Item Name': row.itemName,
    Reason: row.reason,
    Image: row.imageUrl || row.imagePath || '',
  }))

  const workbook = XLSX.utils.book_new()
  const sheet =
    sheetRows.length === 0
      ? XLSX.utils.aoa_to_sheet([
          [
            'Employee Code',
            'Employee Name',
            'Route',
            'Customer Code',
            'Customer Name',
            'Item Code',
            'Item Name',
            'Reason',
            'Image',
          ],
        ])
      : XLSX.utils.json_to_sheet(sheetRows)

  XLSX.utils.book_append_sheet(workbook, sheet, 'Product Reviews')
  XLSX.writeFile(
    workbook,
    `product_reviews_${new Date().toISOString().slice(0, 10)}.xlsx`
  )
}
