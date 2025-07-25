async function getParticipants(activityId) {
  const path = `/api/${activityId}`;
  const request = await fetch(path);
  const response = await request.json();
  return response;
}

async function addParticipant(activityId, participantName) {
  const path = `/api/${activityId}`;
  const data = new URLSearchParams();
  data.append('participant_name', participantName);

  const request = await fetch(path, { method: 'post', body: data });
  const response = await request.json();
  return response;
}

async function removeParticipant(activityId, participantName) {
  const path = `/api/${activityId}`;
  const data = new URLSearchParams();
  data.append('participant_name', `-${participantName}`);

  const request = await fetch(path, { method: 'post', body: data });
  const response = await request.json();
  return response;
}

async function renderParticipantsSection(section) {
  const participants = await getParticipants(section.id);
  
  const span = document.createElement('span');
  span.innerText = 'Participants:'
  section.innerHTML = '';
  section.appendChild(span);

  for (let p of participants) {
    const entry = document.createElement('entry');
    entry.innerText = p;
    section.appendChild(entry);
  }

  const entry = document.createElement('entry');
  entry.innerText = '+';
  entry.classList.add('add');
  entry.addEventListener('click', (e) => {
    e.preventDefault();
    startAddParticipantWorkflow(section, entry);
  });
  section.appendChild(entry);
}

async function updateParticipantsSection(section) {
  await renderParticipantsSection(section);
}

function startAddParticipantWorkflow(section, addSpan) {
  addSpan.classList.add('hidden');

  const miniForm = document.createElement('span');
  miniForm.classList.add('add-form');
  const input = document.createElement('input');
  const submitButton = document.createElement('button');
  submitButton.innerText = 'OK';
  miniForm.appendChild(input);
  miniForm.appendChild(submitButton);
  section.appendChild(miniForm);

  const submit = async (e) => {
    e.preventDefault();
    if (input.value.length > 0)
      await addParticipant(section.id, input.value);
    updateParticipantsSection(section);
  };

  submitButton.addEventListener('click', submit);
  input.addEventListener('keyup', function(e) {
    if (e.key === "Enter") submit(e);
  });

  input.focus();
}

async function setupParticipantSections() {
  const participantsSections = document.querySelectorAll('participants');
  for (let e of participantsSections) {
    await renderParticipantsSection(e);
  }
}

setupParticipantSections();
