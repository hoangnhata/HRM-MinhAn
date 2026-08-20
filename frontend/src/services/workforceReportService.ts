import ExcelJS from 'exceljs';
import api from './api';

export type WorkforceReportType = 'HOSPITAL' | 'DAILY';
export type WorkforceCategory = { key: string; label: string };
export type WorkforceDepartmentRow = {
  departmentId: number;
  departmentName: string;
  counts: Record<string, number>;
  total: number;
};
export type WorkforceDetailRow = {
  employeeId: number;
  employeeCode?: string | null;
  fullName: string;
  departmentId: number;
  departmentName: string;
  positionTitle: string;
  category: string;
  categoryLabel: string;
  employeeStatus: string;
  employmentType?: string | null;
  hireDate?: string | null;
  attendanceStatus?: string | null;
  checkIn?: string | null;
  checkOut?: string | null;
  morningCheckIn?: string | null;
  morningCheckOut?: string | null;
  afternoonCheckIn?: string | null;
  afternoonCheckOut?: string | null;
  workUnits?: number | null;
  lateMinutes?: number | null;
};
export type WorkforceReport = {
  type: WorkforceReportType;
  reportDate: string;
  generatedAt: string;
  categories: WorkforceCategory[];
  rows: WorkforceDepartmentRow[];
  totals: Record<string, number>;
  grandTotal: number;
  departmentCount: number;
  details: WorkforceDetailRow[];
};

const XLSX_MIME = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const COLORS = {
  primary: 'FF006865',
  primaryDark: 'FF004B49',
  header: 'FF087F8C',
  subtitleBg: 'FFDDEDEB',
  subtitleFg: 'FF244846',
  kpiBg: 'FFEFF7F6',
  kpiLabel: 'FF52706E',
  text: 'FF243B3A',
  textMuted: 'FF365B5A',
  white: 'FFFFFFFF',
  alt: 'FFF4F8F8',
  positiveOdd: 'FFE6F3F1',
  positiveEven: 'FFDCEFED',
  totalRow: 'FF006865',
  nameFg: 'FF123B3A',
  statusGreenBg: 'FFDCFCE7',
  statusGreenFg: 'FF166534',
  statusAmberBg: 'FFFEF3C7',
  statusAmberFg: 'FF92400E',
  statusBlueBg: 'FFE0F2FE',
  statusBlueFg: 'FF075985',
  tabDetail: 'FFD99B2B',
};

export async function fetchHospitalWorkforceReport() {
  const { data } = await api.get<WorkforceReport>('/v1/workforce-reports/hospital');
  return data;
}

export async function fetchDailyWorkforceReport(date: string) {
  const { data } = await api.get<WorkforceReport>('/v1/workforce-reports/daily', { params: { date } });
  return data;
}

function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

function formatDateVi(iso: string) {
  const [y, m, d] = iso.split('-');
  return y && m && d ? `${d}/${m}/${y}` : iso;
}

async function assertExcelBlob(data: Blob) {
  const type = (data.type || '').toLowerCase();
  if (type.includes('json') || type.includes('text/')) {
    const text = await data.text();
    try {
      const json = JSON.parse(text) as { message?: string };
      throw new Error(json.message || 'Máy chủ trả lỗi khi tạo file Excel');
    } catch (e) {
      if (e instanceof SyntaxError) {
        throw new Error(text.slice(0, 200) || 'Máy chủ trả lỗi khi tạo file Excel');
      }
      throw e;
    }
  }
  if (data.size < 64) {
    throw new Error('File Excel trống hoặc không hợp lệ');
  }
}

export async function downloadWorkforceReport(type: WorkforceReportType, date?: string) {
  const daily = type === 'DAILY';
  const res = await api.get(`/v1/workforce-reports/${daily ? 'daily' : 'hospital'}/excel`, {
    params: daily ? { date } : undefined,
    responseType: 'blob',
    timeout: 300000,
  });
  await assertExcelBlob(res.data as Blob);
  const blob = new Blob([res.data], { type: XLSX_MIME });
  triggerDownload(blob, daily ? `bao-cao-nhan-luc-di-lam-${date}.xlsx` : 'bao-cao-nhan-luc-toan-vien.xlsx');
}

function employeeStatusLabel(value: string) {
  return (
    ({ ACTIVE: 'Chính thức', PROBATION: 'Thử việc', INTERN: 'Thực tập', ON_LEAVE: 'Tạm nghỉ' } as Record<string, string>)[
      value
    ] || value
  );
}

function attendanceStatusLabel(value?: string | null) {
  return (
    ({
      PRESENT: 'Đi làm đủ',
      PARTIAL: 'Đi làm thiếu ca',
      SEMINAR: 'Hội thảo + đi làm',
      ABSENT: 'Đã check-in',
    } as Record<string, string>)[value || ''] ||
    value ||
    ''
  );
}

function fill(argb: string): ExcelJS.Fill {
  return { type: 'pattern', pattern: 'solid', fgColor: { argb } };
}

function font(opts: Partial<ExcelJS.Font> & { color?: string }): Partial<ExcelJS.Font> {
  const { color, ...rest } = opts;
  return {
    name: 'Arial',
    size: 10,
    ...rest,
    ...(color ? { color: { argb: color } } : {}),
  };
}

function thinBorder(): Partial<ExcelJS.Borders> {
  const edge: Partial<ExcelJS.Border> = { style: 'thin', color: { argb: 'FFD0D7D6' } };
  return { top: edge, left: edge, bottom: edge, right: edge };
}

function styleCell(cell: ExcelJS.Cell, style: Partial<ExcelJS.Style>) {
  if (style.font) cell.font = style.font;
  if (style.fill) cell.fill = style.fill;
  if (style.alignment) cell.alignment = style.alignment;
  if (style.border) cell.border = style.border;
  if (style.numFmt) cell.numFmt = style.numFmt;
}

function applyRange(
  sheet: ExcelJS.Worksheet,
  row: number,
  from: number,
  to: number,
  value: string | number,
  style: Partial<ExcelJS.Style>,
) {
  if (to > from) sheet.mergeCells(row, from, row, to);
  const cell = sheet.getCell(row, from);
  cell.value = value;
  styleCell(cell, style);
  for (let c = from + 1; c <= to; c++) {
    styleCell(sheet.getCell(row, c), style);
  }
}

/** Dự phòng / xuất local — giao diện đồng bộ báo cáo toàn viện (POI). */
export async function downloadWorkforceReportFallback(report: WorkforceReport) {
  const daily = report.type === 'DAILY';
  const dateVi = formatDateVi(report.reportDate);
  const todayVi = formatDateVi(
    `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}-${String(new Date().getDate()).padStart(2, '0')}`,
  );
  const lastCol = report.categories.length + 2; // 1-based: dept + categories + total
  const title = daily
    ? `BÁO CÁO NHÂN LỰC ĐI LÀM HẰNG NGÀY  •  ${dateVi}`
    : 'BÁO CÁO NHÂN LỰC TOÀN VIỆN';

  const topCategory = report.categories
    .map((category) => ({ label: category.label, value: report.totals[category.key] || 0 }))
    .sort((a, b) => b.value - a.value)[0];

  const wb = new ExcelJS.Workbook();
  wb.creator = 'HRM Minh An';
  wb.created = new Date();

  const matrix = wb.addWorksheet(daily ? 'Nhân lực đi làm' : 'Nhân lực toàn viện', {
    views: [{ state: 'frozen', xSplit: 1, ySplit: 6, showGridLines: false, zoomScale: 85 }],
    properties: { tabColor: { argb: COLORS.header } },
  });

  const titleStyle: Partial<ExcelJS.Style> = {
    font: font({ bold: true, size: 16, color: COLORS.white }),
    fill: fill(COLORS.primary),
    alignment: { horizontal: 'center', vertical: 'middle' },
  };
  const subtitleStyle: Partial<ExcelJS.Style> = {
    font: font({ size: 10, color: COLORS.subtitleFg }),
    fill: fill(COLORS.subtitleBg),
    alignment: { horizontal: 'left', vertical: 'middle' },
  };
  const kpiLabelStyle: Partial<ExcelJS.Style> = {
    font: font({ bold: true, size: 9, color: COLORS.kpiLabel }),
    fill: fill(COLORS.kpiBg),
    alignment: { horizontal: 'center', vertical: 'middle' },
  };
  const kpiValueStyle: Partial<ExcelJS.Style> = {
    font: font({ bold: true, size: 14, color: COLORS.primary }),
    fill: fill(COLORS.kpiBg),
    alignment: { horizontal: 'center', vertical: 'middle' },
  };
  const headerStyle: Partial<ExcelJS.Style> = {
    font: font({ bold: true, color: COLORS.white }),
    fill: fill(COLORS.header),
    alignment: { horizontal: 'center', vertical: 'middle', wrapText: true },
    border: thinBorder(),
  };
  const headerLeftStyle: Partial<ExcelJS.Style> = {
    ...headerStyle,
    alignment: { horizontal: 'left', vertical: 'middle', wrapText: true },
  };

  applyRange(matrix, 1, 1, lastCol, title, titleStyle);
  matrix.getRow(1).height = 32;
  applyRange(
    matrix,
    2,
    1,
    lastCol,
    `BỆNH VIỆN ĐA KHOA MINH AN  •  Ngày báo cáo: ${dateVi}  •  Ngày xuất: ${todayVi}`,
    subtitleStyle,
  );
  matrix.getRow(2).height = 24;

  const kpiLabels = [
    daily ? 'THỰC TẾ CÓ MẶT' : 'TỔNG NHÂN LỰC',
    'KHOA / PHÒNG',
    'CHỨC VỤ NHIỀU NHẤT',
    'NGÀY BÁO CÁO',
  ];
  const kpiValues: (string | number)[] = [
    report.grandTotal,
    report.departmentCount,
    `${topCategory?.label || '—'} · ${topCategory?.value || 0}`,
    dateVi,
  ];
  for (let i = 0; i < 4; i++) {
    const from = Math.floor((i * lastCol) / 4) + 1;
    const to = Math.floor(((i + 1) * lastCol) / 4);
    applyRange(matrix, 3, from, to, kpiLabels[i], kpiLabelStyle);
    applyRange(matrix, 4, from, to, kpiValues[i], kpiValueStyle);
  }
  matrix.getRow(3).height = 20;
  matrix.getRow(4).height = 28;

  const headerRow = matrix.getRow(6);
  headerRow.height = 44;
  headerRow.getCell(1).value = 'KHOA / PHÒNG';
  styleCell(headerRow.getCell(1), headerLeftStyle);
  report.categories.forEach((c, i) => {
    const cell = headerRow.getCell(i + 2);
    cell.value = c.label;
    styleCell(cell, headerStyle);
  });
  headerRow.getCell(lastCol).value = 'TỔNG';
  styleCell(headerRow.getCell(lastCol), headerStyle);

  report.rows.forEach((row, idx) => {
    const r = matrix.getRow(7 + idx);
    r.height = 23;
    const even = (7 + idx) % 2 === 0;
    const bg = even ? COLORS.alt : COLORS.white;
    const deptStyle: Partial<ExcelJS.Style> = {
      font: font({ bold: true, color: COLORS.nameFg }),
      fill: fill(bg),
      alignment: { horizontal: 'left', vertical: 'middle' },
      border: thinBorder(),
    };
    r.getCell(1).value = row.departmentName;
    styleCell(r.getCell(1), deptStyle);

    report.categories.forEach((c, i) => {
      const value = row.counts[c.key] || 0;
      const cell = r.getCell(i + 2);
      cell.value = value;
      styleCell(cell, {
        font: font({ color: value > 0 ? COLORS.primary : COLORS.textMuted, bold: value > 0 }),
        fill: fill(value > 0 ? (even ? COLORS.positiveEven : COLORS.positiveOdd) : bg),
        alignment: { horizontal: 'center', vertical: 'middle' },
        border: thinBorder(),
      });
    });

    const totalCell = r.getCell(lastCol);
    totalCell.value = row.total;
    styleCell(totalCell, {
      font: font({ bold: true, color: COLORS.primary }),
      fill: fill(even ? 'FFE3F1EF' : 'FFEDF7F5'),
      alignment: { horizontal: 'center', vertical: 'middle' },
      border: thinBorder(),
    });
  });

  const totalRowIdx = 7 + report.rows.length;
  const totalRow = matrix.getRow(totalRowIdx);
  totalRow.height = 26;
  const totalStyle: Partial<ExcelJS.Style> = {
    font: font({ bold: true, color: COLORS.white }),
    fill: fill(COLORS.totalRow),
    alignment: { horizontal: 'center', vertical: 'middle' },
    border: thinBorder(),
  };
  totalRow.getCell(1).value = 'TỔNG CỘNG';
  styleCell(totalRow.getCell(1), totalStyle);
  report.categories.forEach((c, i) => {
    const cell = totalRow.getCell(i + 2);
    cell.value = report.totals[c.key] || 0;
    styleCell(cell, totalStyle);
  });
  totalRow.getCell(lastCol).value = report.grandTotal;
  styleCell(totalRow.getCell(lastCol), {
    ...totalStyle,
    font: font({ bold: true, size: 11, color: COLORS.white }),
    fill: fill(COLORS.primaryDark),
  });

  matrix.autoFilter = {
    from: { row: 6, column: 1 },
    to: { row: Math.max(6, totalRowIdx - 1), column: lastCol },
  };
  matrix.getColumn(1).width = 36;
  for (let i = 2; i < lastCol; i++) matrix.getColumn(i).width = 16;
  matrix.getColumn(lastCol).width = 11;
  matrix.pageSetup = {
    orientation: 'landscape',
    fitToPage: true,
    fitToWidth: 1,
    fitToHeight: 0,
  };

  // Sheet chi tiết
  const detailHeaders = ['STT', 'Mã NV', 'Họ và tên', 'Khoa/Phòng', 'Chức vụ', 'Trạng thái NV'];
  if (daily) detailHeaders.push('Giờ vào', 'Giờ ra', 'Công', 'Phút muộn/sớm', 'Trạng thái công');
  const detailLast = detailHeaders.length;

  const detail = wb.addWorksheet('Chi tiết nhân viên', {
    views: [{ state: 'frozen', ySplit: 4, showGridLines: false, zoomScale: 90 }],
    properties: { tabColor: { argb: COLORS.tabDetail } },
  });

  applyRange(
    detail,
    1,
    1,
    detailLast,
    daily ? `CHI TIẾT NHÂN LỰC ĐI LÀM NGÀY ${dateVi}` : 'CHI TIẾT NHÂN LỰC TOÀN VIỆN',
    titleStyle,
  );
  detail.getRow(1).height = 30;
  applyRange(
    detail,
    2,
    1,
    detailLast,
    `BỆNH VIỆN ĐA KHOA MINH AN  •  Tổng số: ${report.details.length} nhân viên`,
    subtitleStyle,
  );
  detail.getRow(2).height = 23;

  const dHeader = detail.getRow(4);
  dHeader.height = 32;
  detailHeaders.forEach((h, i) => {
    const cell = dHeader.getCell(i + 1);
    cell.value = h;
    styleCell(cell, i === 0 || i >= 5 ? headerStyle : headerLeftStyle);
  });

  report.details.forEach((row, idx) => {
    const r = detail.getRow(5 + idx);
    r.height = 22;
    const even = (5 + idx) % 2 === 0;
    const bg = even ? COLORS.alt : COLORS.white;
    const left: Partial<ExcelJS.Style> = {
      font: font({ color: COLORS.text }),
      fill: fill(bg),
      alignment: { horizontal: 'left', vertical: 'middle' },
      border: thinBorder(),
    };
    const center: Partial<ExcelJS.Style> = {
      font: font({ color: COLORS.textMuted }),
      fill: fill(bg),
      alignment: { horizontal: 'center', vertical: 'middle' },
      border: thinBorder(),
    };
    const name: Partial<ExcelJS.Style> = {
      font: font({ bold: true, color: COLORS.nameFg }),
      fill: fill(bg),
      alignment: { horizontal: 'left', vertical: 'middle' },
      border: thinBorder(),
    };

    const values: (string | number)[] = [
      idx + 1,
      row.employeeCode || '',
      row.fullName,
      row.departmentName,
      row.positionTitle,
      employeeStatusLabel(row.employeeStatus),
    ];
      if (daily) {
        const inn = row.morningCheckIn || row.checkIn || '';
        const rawOut = row.afternoonCheckOut || row.checkOut || '';
        let out = '';
        if (rawOut && inn) {
          const [ih, im] = inn.split(':').map(Number);
          const [oh, om] = rawOut.split(':').map(Number);
          const minutes = oh * 60 + om - (ih * 60 + im);
          if (rawOut > inn && minutes >= 120) out = rawOut;
        } else if (rawOut && !inn) {
          out = rawOut;
        }
        values.push(inn, out, Number(row.workUnits) || 0, Number(row.lateMinutes) || 0, attendanceStatusLabel(row.attendanceStatus));
      }

    values.forEach((v, i) => {
      const cell = r.getCell(i + 1);
      cell.value = v;
      if (i === 2) styleCell(cell, name);
      else if (i === 0 || i === 1 || i === 6 || (daily && i >= 7)) styleCell(cell, center);
      else styleCell(cell, left);

      if (daily && i === 9) {
        cell.numFmt = '0.00';
      }
      if (daily && i === 11) {
        const st = row.attendanceStatus;
        if (st === 'PRESENT') {
          styleCell(cell, {
            font: font({ bold: true, color: COLORS.statusGreenFg }),
            fill: fill(COLORS.statusGreenBg),
            alignment: { horizontal: 'center', vertical: 'middle' },
            border: thinBorder(),
          });
        } else if (st === 'PARTIAL' || st === 'ABSENT') {
          styleCell(cell, {
            font: font({ bold: true, color: COLORS.statusAmberFg }),
            fill: fill(COLORS.statusAmberBg),
            alignment: { horizontal: 'center', vertical: 'middle' },
            border: thinBorder(),
          });
        } else if (st === 'SEMINAR') {
          styleCell(cell, {
            font: font({ bold: true, color: COLORS.statusBlueFg }),
            fill: fill(COLORS.statusBlueBg),
            alignment: { horizontal: 'center', vertical: 'middle' },
            border: thinBorder(),
          });
        }
      }
    });
  });

  if (report.details.length > 0) {
    detail.autoFilter = {
      from: { row: 4, column: 1 },
      to: { row: 4 + report.details.length, column: detailLast },
    };
  }

  const detailWidths = daily
    ? [7, 16, 28, 34, 23, 21, 17, 12, 12, 10, 16, 20]
    : [7, 16, 28, 34, 23, 21, 17];
  detailWidths.forEach((w, i) => {
    detail.getColumn(i + 1).width = w;
  });
  detail.pageSetup = {
    orientation: 'landscape',
    fitToPage: true,
    fitToWidth: 1,
    fitToHeight: 0,
  };

  const buffer = await wb.xlsx.writeBuffer();
  const blob = new Blob([buffer], { type: XLSX_MIME });
  triggerDownload(
    blob,
    daily ? `bao-cao-nhan-luc-di-lam-${report.reportDate}.xlsx` : 'bao-cao-nhan-luc-toan-vien.xlsx',
  );
}
