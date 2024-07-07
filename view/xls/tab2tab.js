export function TableToTable(tab) {
  // Create a table element
  const table = document.createElement('table');
  table.setAttribute('border', '1');

  // Add table header row
  const thead = document.createElement('thead');
  const headerRow = document.createElement('tr');
  for(const field of tab.fields){
    const th = document.createElement('th');
    th.textContent = field;
    headerRow.appendChild(th);      
  }
  thead.appendChild(headerRow);
  table.appendChild(thead);

  // Add table body rows
  const tbody = document.createElement('tbody');
  for(const line of tab.values){
    
    const tr = document.createElement('tr');
      
    for(const value of line){
      const td = document.createElement('td');
			td.textContent = value;
      tr.appendChild(td);
		}
    tbody.appendChild(tr);
  }
  table.appendChild(tbody);
  // Return the table element
  return table;
}