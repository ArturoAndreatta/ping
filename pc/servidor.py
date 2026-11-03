"""
Endereco do servidor (Firebase e disparador de avisos). Quem hospedar o proprio Ping troca so este arquivo
(e no app: opcoes do Firebase em app/lib/main.dart, chave VAPID em app/lib/push.dart). Nada aqui e segredo: a chave web do Firebase so identifica o projeto, quem
protege os dados sao as regras do banco (database.rules.json).
"""
PROJETO = "ping-celular"
DB = f"https://{PROJETO}-default-rtdb.firebaseio.com"
API_KEY = "AIzaSyABdomDfEhtp3W-LE9SeRLq7f1iiK8JOns"
SITE = f"https://{PROJETO}.web.app/"          # app do celular (o QR do painel abre aqui)
AVISOS = "https://ping-avisos.notificacoes-push.workers.dev/aviso"  # disparador dos avisos push (pasta disparador/)
REPO = "ArturoAndreatta/ping"                  # releases do GitHub: atualizacao do programa do PC
