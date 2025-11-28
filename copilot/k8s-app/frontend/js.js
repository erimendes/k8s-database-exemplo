// Conteúdo CORRIGIDO
function addMsg(m){
  const lista = document.getElementById("lista");
  const li=document.createElement("li");
  li.className="list-group-item";
  // Formatando data
  const date = new Date(m.criado);
  const formattedDate = date.toLocaleTimeString('pt-BR') + ' ' + date.toLocaleDateString('pt-BR');

  li.innerHTML=`<b>${m.usuario}</b>: ${m.mensagem}
  <br><small>${formattedDate}</small>`;
  lista.prepend(li);
}

document.addEventListener('DOMContentLoaded', () => {
    const lista = document.getElementById("lista");
    lista.innerHTML = ''; // Limpa o item de carregamento

    // 1. WebSocket
    const socket = io();
    socket.on("nova_mensagem", addMsg);

    // 2. Fetch de mensagens existentes
    fetch("/api/mensagens")
        .then(r => r.json())
        .then(msgs => msgs.forEach(addMsg))
        .catch(err => {
             lista.innerHTML = '<li class="list-group-item list-group-item-danger">Erro ao carregar mensagens.</li>';
             console.error("Erro ao carregar mensagens:", err);
        });

    // 3. Listener do botão de envio
    const btnSalvar = document.getElementById("btn_salvar");

    btnSalvar.onclick = async () => {
        // CORREÇÃO: Usar document.getElementById para obter os elementos
        const nomeInput = document.getElementById("nome"); 
        const mensagemInput = document.getElementById("mensagem");

        const nome = nomeInput.value.trim();
        const mensagem = mensagemInput.value.trim();
        const resp = document.getElementById("resposta");

        if(nome.length < 3 || mensagem.length < 3){
            resp.innerHTML = "Preencha corretamente!";
            resp.style.color = "red";
            return;
        }

        btnSalvar.disabled = true;

        const f = await fetch("/api/mensagem", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ usuario: nome, mensagem })
        });

        const dados = await f.json();
        
        btnSalvar.disabled = false;

        if(dados.sucesso){
            resp.innerHTML = "Mensagem enviada!";
            resp.style.color = "green";
            mensagemInput.value = "";
        } else {
            resp.innerHTML = "Erro: " + (dados.erro || "Falha desconhecida");
            resp.style.color = "red";
        }
    };
});
