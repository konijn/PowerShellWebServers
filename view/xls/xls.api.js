import {jsonToTable} from '/xls/json2tab.js';

// script.js (ES6 module)
export function apiDemo() {
    console.log('Doing something!');

	document.addEventListener('DOMContentLoaded', (event) => {
		fetch('/xls/api', {
			method: 'GET',
			headers: {
				'Accept': 'application/json'
			}
		})
		.then(response => {
			if (!response.ok) {
				throw new Error('Network response was not ok');
			}
			return response.json();
		})
		.then(data => {
			console.log(Object.keys(data[0]));
			document.getElementById('json').value = JSON.stringify(data);
			document.getElementById('table').appendChild(jsonToTable(data));
		})
		.catch(error => {
			console.error('There has been a problem with your fetch operation:', error);
		});
	});
}