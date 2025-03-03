from prometheus_client import start_http_server, Gauge
import pandas as pd
import time
import glob
import os

# Defina uma métrica Prometheus com o método como um dos rótulos
operation_gauge = Gauge(
    'objs_benchmark',
    'Dados de benchmark',
    ['operation', 'region', 'tool', 'size', 'workers', 'quantity']
)

def read_csv_and_update_metrics():
    report_folder = '/home/ubuntu/s3-tester/report/'

    # Limpe as métricas existentes
    operation_gauge.clear()

    # Processar o report-inconsistencies.csv - Sempre
    inconsistencies_file = os.path.join(report_folder, 'report-inconsistencies.csv')
    if os.path.exists(inconsistencies_file):
        print(f'Processing file: {inconsistencies_file}')
        df = pd.read_csv(inconsistencies_file)

        # Verificar o formato do CSV e processar adequadamente
        if 'command' in df.columns:
            for _, row in df.iterrows():
                # Verificar se a linha contém valores válidos
                if pd.notna(row['command']) and pd.notna(row['time']):
                    labels = {
                        'operation': row['command'],
                        'region': row['profile'],
                        'tool': row['client'],
                        'size': str(row['size']),
                        'workers': str(row['workers']),
                        'quantity': str(row['quantity'])
                    }
                    operation_gauge.labels(**labels).set(row['time'])
    else:
        print(f"Arquivo {inconsistencies_file} não encontrado.")

    # Processar o processed_data.csv mais recente
    processed_files = glob.glob(os.path.join(report_folder, '*processed_data.csv'))
    if processed_files:
        latest_processed_file = max(processed_files, key=os.path.getmtime)
        print(f'Processing file: {latest_processed_file}')
        df = pd.read_csv(latest_processed_file)

        # Verificar o formato do CSV e processar adequadamente
        if 'operation' in df.columns:
            for _, row in df.iterrows():
                # Verificar se a linha contém valores válidos
                if pd.notna(row['operation']) and pd.notna(row['avg']):
                    labels = {
                        'operation': row['operation'],
                        'region': row['region'],
                        'tool': row['tool'],
                        'size': str(row['size']),
                        'workers': str(row['workers']),
                        'quantity': str(row['quantity'])
                    }
                    operation_gauge.labels(**labels).set(row['avg'])
    else:
        print("Nenhum arquivo processed_data.csv encontrado.")

if __name__ == '__main__':
    # Inicie o servidor HTTP na porta 8000
    start_http_server(8000)
    while True:
        read_csv_and_update_metrics()
        time.sleep(600)  # Atualize a cada 600 segundos (10 minutos)
