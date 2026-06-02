import time
import numpy as np
import matplotlib.pyplot as plt
import datetime
import matplotlib.dates as mdates
from ADCDifferentialPi import ADCDifferentialPi
import csv
import os
import atexit # closes file if loop crashes

SENSITIVITY = 50000  # nT per volt

OFFSET_1 = 0.0
OFFSET_2 = 0.0
OFFSET_3 = 0.0

values1, values2, values3, values_total, times = [], [], [], [], []

adc = ADCDifferentialPi(0x68, 0x69, 18)

# ---------------- PLOT SETUP ----------------
fig, axs = plt.subplots(4, 1, figsize=(10, 8), sharex=True)

line1, = axs[0].plot([], [], color='red')
line2, = axs[1].plot([], [], color='green')
line3, = axs[2].plot([], [], color='blue')
line4, = axs[3].plot([], [], color='black')

axs[0].set_ylabel('Bx (nT)')
axs[0].set_title('X Component')
axs[0].grid()

axs[1].set_ylabel('By (nT)')
axs[1].set_title('Y Component')
axs[1].grid()

axs[2].set_ylabel('Bz (nT)')
axs[2].set_title('Z Component')
axs[2].grid()

axs[3].set_ylabel('Total (nT)')
axs[3].set_xlabel('UTC Time')
axs[3].set_title('Total Magnetic Field')
axs[3].grid()

for ax in axs:
    ax.xaxis.set_major_locator(mdates.AutoDateLocator())
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d\n%H:%M:%S'))

plt.ion()
fig.autofmt_xdate()

# ---------------- FILE STATE ----------------
current_date = None
csv_file = None
csv_writer = None

# ---------------- MINUTE BUFFER ----------------
minute_bx = []
minute_by = []
minute_bz = []
minute_total = []

last_minute = None

# ---------------- CLEAN EXIT ----------------
def close_file():
    if csv_file is not None:
        csv_file.close()

atexit.register(close_file)

# ================= MAIN LOOP =================
while True:

    # ---------- TIME ----------
    current_time = datetime.datetime.utcnow()
    date_str = current_time.strftime("%Y-%m-%d")
    time_str = current_time.strftime("%H:%M:%S")

    # ---------- SENSOR ----------
    bx = (adc.read_voltage(1) - OFFSET_1) * SENSITIVITY
    by = (adc.read_voltage(2) - OFFSET_2) * SENSITIVITY
    bz = (adc.read_voltage(3) - OFFSET_3) * SENSITIVITY

    b_total = np.sqrt(bx**2 + by**2 + bz**2)

    # ---------- CSV FILE HANDLING ----------
    if date_str != current_date:
        if csv_file is not None:
            csv_file.close()

        os.makedirs("data", exist_ok=True)
        filename = f"data/geomagnetic_{date_str}.csv"
        file_exists = os.path.isfile(filename)

        csv_file = open(filename, "a", newline="")
        csv_writer = csv.writer(csv_file)

        if not file_exists:
            csv_writer.writerow([
                "Date", "Time",
                "Bx (nT)", "By (nT)", "Bz (nT)", "Total (nT)"
            ])

        current_date = date_str

    # ---------- RAW CSV LOG (EVERY SECOND) ---------- # data logged in csv, one row every second
    if csv_writer is not None:
        csv_writer.writerow([date_str, time_str, bx, by, bz, b_total])
        csv_file.flush()

    # ---------- MINUTE AVERAGING ---------- # minute average data plotted on live graph
    current_minute = current_time.replace(second=0, microsecond=0)

    minute_bx.append(bx) # 60 seconds of data stored in memory
    minute_by.append(by)
    minute_bz.append(bz)
    minute_total.append(b_total)

    if last_minute is None:
        last_minute = current_minute

    if current_minute != last_minute:

        avg_bx = np.mean(minute_bx)
        avg_by = np.mean(minute_by)
        avg_bz = np.mean(minute_bz)
        avg_total = np.mean(minute_total)

        avg_time = last_minute

        values1.append(avg_bx) # one point per minute plotted
        values2.append(avg_by)
        values3.append(avg_bz)
        values_total.append(avg_total)
        times.append(avg_time)

        minute_bx.clear() # resets for next minute
        minute_by.clear()
        minute_bz.clear()
        minute_total.clear()

        last_minute = current_minute

    # ---------- PLOT UPDATE ----------
    line1.set_data(times, values1)
    line2.set_data(times, values2)
    line3.set_data(times, values3)
    line4.set_data(times, values_total)

    for ax in axs:
        ax.relim()
        ax.autoscale_view() # updates the graph live

    plt.pause(0.01)

    # ---------- SAMPLING RATE ----------
    time.sleep(1)