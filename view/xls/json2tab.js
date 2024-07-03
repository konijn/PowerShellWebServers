export function jsonToTable(jsonArray) {
    // Create a table element
    var table = document.createElement('table');
    table.setAttribute('border', '1');

    // Add table header row
    var thead = document.createElement('thead');
    var headerRow = document.createElement('tr');
    Object.keys(jsonArray[0]).forEach(function(key, value) {
        var th = document.createElement('th');
        th.textContent = key;
        headerRow.appendChild(th);
    });
    thead.appendChild(headerRow);
    table.appendChild(thead);

    // Add table body rows
    var tbody = document.createElement('tbody');
    jsonArray.forEach(function(object) {
        var tr = document.createElement('tr');
        Object.keys(object).forEach(function(key) {
            var td = document.createElement('td');
			if(key == "uri"){
				td.innerHTML = `<a href="${object[key]}">${object[key]}</a>`;
			}else{
				td.textContent = object[key];
			}
            tr.appendChild(td);
        });
        tbody.appendChild(tr);
    });
    table.appendChild(tbody);

    // Return the table element
    return table;
}