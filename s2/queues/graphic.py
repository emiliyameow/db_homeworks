import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("/Users/emiliazagitova/itis/bd/db_homeworks/s2/queues/lagmetrics.csv")
plt.plot(df['unix_seconds'], df['lag_seconds'])
plt.xlabel('Время (секунды с эпохи)')
plt.ylabel('Лаг очереди (сек)')
plt.title('Рост лага при увеличении нагрузки')
plt.show()