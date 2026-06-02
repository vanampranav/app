import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { WeeklyMeals, WeeklyWorkouts } from './ai-coach-parser';
import { ELEFIT_LOGO } from './pdf-assets';

export interface PDFData {
    headerData: {
        prompt: string;
        calories: number;
        workoutFocus: string;
        genDate: string;
    };
    parsedMeals: WeeklyMeals | null;
    parsedWorkouts: WeeklyWorkouts | null;
    scheduleDates: {
        dayName: string;
        dateNum: string;
        fullDate: Date;
    }[];
}

export const generatePlanPDF = (data: PDFData) => {
    const { headerData, parsedMeals, parsedWorkouts, scheduleDates } = data;
    // Orientation: Landscape
    const doc = new jsPDF('l', 'mm', 'a4');
    const primaryColor = [204, 216, 83]; // #CCD853
    const accentColor = [12, 12, 12]; // Dark background

    // Vibrant Meal color theme
    const mealColors: Record<string, [number, number, number]> = {
        Breakfast: [255, 140, 0], // Vivid Orange
        Lunch: [0, 180, 80],       // Deep Fresh Green
        Snacks: [0, 120, 255],     // Electric Blue
        Dinner: [120, 50, 255],    // Royal Purple
    };

    const mealRowBgColors: Record<string, [number, number, number]> = {
        Breakfast: [255, 246, 235],
        Lunch: [238, 250, 242],
        Snacks: [238, 244, 255],
        Dinner: [248, 244, 255],
    };

    const logoAlias = 'logo_elefit';

    const drawHeader = (showSummary: boolean = false) => {
        const width = doc.internal.pageSize.getWidth();
        // Background Header
        doc.setFillColor(accentColor[0], accentColor[1], accentColor[2]);
        doc.rect(0, 0, width, 25, 'F');

        // Logo Integration with alias for performance
        try {
            doc.addImage(ELEFIT_LOGO, 'PNG', 15, 6, 35, 12, logoAlias, 'FAST');
        } catch (e) {
            doc.setTextColor(primaryColor[0], primaryColor[1], primaryColor[2]);
            doc.setFont('helvetica', 'bold');
            doc.setFontSize(22);
            doc.text('ELEFIT', 15, 17);
        }

        if (showSummary) {
            doc.setTextColor(220, 220, 220);
            doc.setFontSize(7.5);
            doc.setFont('helvetica', 'normal');

            const rightX = width - 15;
            const promptStr = (headerData.prompt || 'Custom Plan').toUpperCase();
            const focusStr = (headerData.workoutFocus || 'Personalized').toUpperCase();
            const calStr = (headerData.calories || 0).toString();
            const dateStr = new Date(headerData.genDate || new Date()).toLocaleDateString();

            doc.text(`PLAN: ${promptStr}`, rightX, 9, { align: 'right' });
            doc.text(`CALORIES: ${calStr} KCAL  |  FOCUS: ${focusStr}`, rightX, 15, { align: 'right' });
            doc.text(`DATE: ${dateStr}`, rightX, 21, { align: 'right' });
        }
    };

    drawHeader(true); // First page gets summary
    let currentY = 40;

    // --- MEAL PLAN SECTION ---
    if (parsedMeals) {
        scheduleDates.forEach((date, dayIdx) => {
            // One page per day
            if (dayIdx > 0) {
                doc.addPage('l');
                drawHeader(false); // No summary on subsequent pages
                currentY = 40;
            }

            const dayMeals = parsedMeals[dayIdx] || {};
            const mealTimes = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];
            const tableBody: any[] = [];

            mealTimes.forEach((time) => {
                const items = dayMeals[dayIdx] || dayMeals[time] || [];
                items.forEach((item, itemIdx) => {
                    tableBody.push([
                        { content: itemIdx === 0 ? time.toUpperCase() : '', styles: { textColor: mealColors[time], fontStyle: 'bold' } },
                        item.name,
                        item.quantity,
                        `${item.calories} kcal`,
                        time
                    ]);
                });
            });

            // Section Header (Day) - Rounded look
            doc.setFillColor(30, 30, 30);
            doc.roundedRect(15, currentY - 5, 270, 10, 2, 2, 'F');
            doc.setTextColor(primaryColor[0], primaryColor[1], primaryColor[2]);
            doc.setFontSize(12);
            doc.setFont('helvetica', 'bold');
            doc.text(`DAY ${dayIdx + 1}: ${date.dayName} (${date.dateNum})`, 25, currentY + 1.5);
            currentY += 10;

            if (tableBody.length > 0) {
                // Dynamic page fitting: adjust font and padding based on row count
                let fontSize = 9;
                let cellPadding = 3.5;

                if (tableBody.length > 22) {
                    fontSize = 7;
                    cellPadding = 1.2;
                } else if (tableBody.length > 16) {
                    fontSize = 8;
                    cellPadding = 2;
                }

                autoTable(doc, {
                    startY: currentY,
                    margin: { left: 15, right: 15 },
                    head: [['MEAL', 'FOOD ITEM', 'QUANTITY', 'CALORIES']],
                    body: tableBody.map(row => row.slice(0, 4)),
                    theme: 'grid',
                    headStyles: {
                        fillColor: [20, 20, 20],
                        textColor: [255, 255, 255],
                        fontSize: fontSize,
                        fontStyle: 'bold',
                        halign: 'center'
                    },
                    styles: {
                        fontSize: fontSize,
                        cellPadding: cellPadding,
                        textColor: [40, 40, 40],
                        valign: 'middle',
                        lineWidth: 0.1,
                        lineColor: [220, 220, 220]
                    },
                    columnStyles: {
                        0: { cellWidth: 40, halign: 'center' },
                        1: { fontStyle: 'bold' },
                        2: { cellWidth: 55, halign: 'center' },
                        3: { cellWidth: 45, halign: 'center' }
                    },
                    didParseCell: (data) => {
                        if (data.section === 'body') {
                            const time = tableBody[data.row.index][4];
                            if (mealRowBgColors[time]) {
                                data.cell.styles.fillColor = mealRowBgColors[time];
                            }
                        }
                    },
                    didDrawPage: (data) => {
                        // Crucially, didDrawPage ONLY draws on the current page. 
                        // We check the document's actual page info.
                        const isFirstPage = (doc as any).internal.getCurrentPageInfo().pageNumber === 1;
                        drawHeader(isFirstPage);
                    },
                });

                // Draw rounded border around the whole table (after it finishes)
                const finalY = (doc as any).lastAutoTable.finalY;
                if (finalY > currentY) {
                    doc.setDrawColor(30, 30, 30);
                    doc.setLineWidth(0.4);
                    doc.roundedRect(15, currentY, 267, finalY - currentY, 2, 2, 'S');
                }
                currentY = finalY + 15;
            } else {
                doc.setFontSize(10);
                doc.setTextColor(150, 150, 150);
                doc.text('Your body needs rest - no meals scheduled for today.', 20, currentY);
            }
        });
    }

    // --- WORKOUT PLAN SECTION ---
    if (parsedWorkouts) {
        doc.addPage('l');
        drawHeader(false);
        currentY = 40;

        doc.setTextColor(0, 0, 0);
        doc.setFontSize(15);
        doc.setFont('helvetica', 'bold');
        doc.text('WEEKLY WORKOUT SCHEDULE', 15, currentY);
        currentY += 12;

        scheduleDates.forEach((date, index) => {
            const workout = parsedWorkouts[index];
            if (!workout) return;

            // Two days per page
            if (index > 0 && index % 2 === 0) {
                doc.addPage('l');
                drawHeader(false);
                currentY = 40;
            }

            doc.setFillColor(245, 245, 245);
            doc.roundedRect(15, currentY - 5, 270, 9, 1.5, 1.5, 'F');
            doc.setTextColor(0, 0, 0);
            doc.setFontSize(9);
            doc.setFont('helvetica', 'bold');
            doc.text(`${date.dayName.toUpperCase()} - ${workout.isRestDay ? 'REST DAY' : workout.name.toUpperCase()}`, 25, currentY + 1);

            // Fixed duration logic: Hide if 0mins, 0 mins, 0 min, etc.
            const durationStr = workout.duration?.toString().toLowerCase().trim() || '';
            const isZeroDuration = /^0\s*(mins?|minutes?|)$/.test(durationStr);
            const hasValidDuration = !workout.isRestDay && durationStr !== '' && !isZeroDuration;

            if (!workout.isRestDay && hasValidDuration) {
                doc.setTextColor(120, 120, 120);
                doc.setFont('helvetica', 'normal');
                doc.text(`Duration: ${workout.duration}`, 280, currentY + 1, { align: 'right' });
            }

            currentY += 10;

            if (!workout.isRestDay) {
                const workoutTableBody = workout.exercises.map(ex => [ex]);
                autoTable(doc, {
                    startY: currentY,
                    margin: { left: 20 },
                    body: workoutTableBody,
                    theme: 'plain',
                    styles: { fontSize: 8.5, cellPadding: 1.5 },
                });
                currentY = (doc as any).lastAutoTable.finalY + 12;
            } else {
                doc.setFontSize(8);
                doc.setTextColor(150, 150, 150);
                doc.setFont('helvetica', 'italic');
                doc.text('Take this time to recover and stay hydrated.', 22, currentY);
                currentY += 12;
            }
        });
    }

    // --- FOOTER ---
    const totalPages = (doc as any).internal.getNumberOfPages();
    for (let i = 1; i <= totalPages; i++) {
        doc.setPage(i);
        doc.setFontSize(7);
        doc.setTextColor(180, 180, 180);
        const pageWidth = doc.internal.pageSize.getWidth();
        doc.text('GENERATED BY ELEFIT AI COACH • FUEL YOUR AMBITION • WWW.ELEFIT.COM', pageWidth / 2, 196, { align: 'center' });
        doc.text(`PAGE ${i} OF ${totalPages}`, pageWidth - 15, 196, { align: 'right' });

        // Medical Disclaimer
        doc.setFontSize(5);
        doc.setTextColor(200, 200, 200);
        const disclaimer = "This site offers health, fitness and nutritional information and is designed for educational purposes only. You should not rely on this information as a substitute for, nor does it replace, professional medical advice, diagnosis, or treatment. If you have any concerns or questions about your health, you should always consult with a physician or other health-care professional. Do not disregard, avoid or delay obtaining medical or health related advice from your health-care professional because of something you may have read on this site. The use of any information provided on this site is solely at your own risk.";
        doc.text(disclaimer, pageWidth / 2, 202, { align: 'center', maxWidth: 260 });
    }

    doc.save(`EleFit_Plan_${headerData.prompt.replace(/\s+/g, '_')}.pdf`);
};
